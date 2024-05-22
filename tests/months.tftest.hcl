
mock_provider "azuread" {}

variables {
  # just some random UUID
  application_id = "/applications/897af0a3-9901-4286-8e0c-cdad6c10d970"
  # test defaults
  # unit = "months"
  # validity = 24
  # overlap = 3
  # jitter = "5m"

  one_valid = 18 # duration, where only one secret is valid
  M_to_h    = 365 / 12 * 24
}

# plan vs apply time difference leads to empty active_secret on initial apply.
# The -1m jitter simulates this issue and expects an error
run "no_jitter" {
  variables {
    jitter = "-5m"
  }

  expect_failures = [
    output.active_secret
  ]
}

run "initial" {
  assert {
    condition     = output.active_secret == "blue"
    error_message = "Initial active secret must be 'blue'."
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].start_date == timestamp()
    error_message = "'blue' must be valid immediately."
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].end_date == timeadd(output.secrets_lifecycle["blue"].start_date, "${var.validity * var.M_to_h}h")
    error_message = "'blue' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = timecmp(output.secrets_lifecycle["blue"].rotation_date, timeadd(output.secrets_lifecycle["green"].end_date, "-${var.overlap * var.M_to_h + 6 * 24}h")) >= 0 && timecmp(output.secrets_lifecycle["blue"].rotation_date, timeadd(output.secrets_lifecycle["green"].end_date, "-${var.overlap * var.M_to_h - 6 * 24}h")) <= 0
    error_message = "'blue' secret must be rotated ${var.overlap} ${var.unit} (within +- 6 days) before end_date of 'green' secret."
  }
  assert {
    condition     = azuread_application_password.blue.display_name == "blue;not_before=${formatdate(var.date_format, timestamp())}"
    error_message = "'blue' secret description must include proper not_before information."
  }

  assert {
    condition     = !output.secrets_lifecycle["green"].valid
    error_message = "Initially, 'green' secret must not be valid."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].end_date == timeadd(output.secrets_lifecycle["green"].start_date, "${var.validity * var.M_to_h}h")
    error_message = "'green' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].start_date == timeadd(output.secrets_lifecycle["blue"].end_date, "-${var.overlap * var.M_to_h}h")
    error_message = "'green' secret must start ${var.overlap} ${var.unit} before 'blue' end_date."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].rotation_date == output.secrets_lifecycle["green"].end_date
    error_message = "'green' secret must be rotated at its end_date."
  }
  assert {
    condition     = azuread_application_password.green.display_name == "green;not_before=${formatdate(var.date_format, output.secrets_lifecycle["green"].start_date)}"
    error_message = "'green' secret description must include proper not_before information."
  }
}

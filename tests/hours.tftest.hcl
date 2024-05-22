
mock_provider "azuread" {}

variables {
  # just some random UUID
  application_id = "/applications/897af0a3-9901-4286-8e0c-cdad6c10d970"
  unit           = "hours"
  validity       = 24
  overlap        = 6
  one_valid      = 12 # duration, where only one secret is valid
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
    condition     = output.secrets_lifecycle["blue"].end_date == timeadd(output.secrets_lifecycle["blue"].start_date, "${var.validity}h")
    error_message = "'blue' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].rotation_date == timeadd(output.secrets_lifecycle["blue"].end_date, "${var.one_valid}h")
    error_message = "'blue' secret must be rotated ${var.overlap} ${var.unit} before end_date of 'green' secret."
  }

  assert {
    condition     = !output.secrets_lifecycle["green"].valid
    error_message = "Initially, 'green' secret must not be valid."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].end_date == timeadd(output.secrets_lifecycle["green"].start_date, "${var.validity}h")
    error_message = "'green' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].start_date == timeadd(output.secrets_lifecycle["blue"].end_date, "-${var.overlap}h")
    error_message = "'green' secret must start ${var.overlap} ${var.unit} before 'blue' end_date."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].rotation_date == output.secrets_lifecycle["green"].end_date
    error_message = "'green' secret must be rotated at its end_date."
  }
}

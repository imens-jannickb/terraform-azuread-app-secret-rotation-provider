
mock_provider "azuread" {}

variables {
  # just some random UUID
  application_id = "/applications/897af0a3-9901-4286-8e0c-cdad6c10d970"
  unit           = "minutes"
  validity       = 3
  overlap        = 1
  date_format    = "hh:mm:ss"

  one_valid = 1 # duration, where only one secret is valid
  jitter    = "2s"
}

# plan vs apply time difference leads to empty active_secret on initial apply.
# The -1m jitter simulates this issue and expects an error
run "no_jitter" {
  variables {
    jitter = "-1m"
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
    condition = timecmp(output.secrets_lifecycle["blue"].start_date, timeadd(timestamp(), "-5s")) >= 0
    #condition = output.secrets_lifecycle["blue"].start_date == timestamp()
    error_message = "'blue' must be valid immediately."
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].end_date == timeadd(output.secrets_lifecycle["blue"].start_date, "${var.validity}m")
    error_message = "'blue' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].rotation_date == timeadd(output.secrets_lifecycle["blue"].end_date, "${var.one_valid}m")
    error_message = "'blue' secret must be rotated ${var.overlap} ${var.unit} before end_date of 'green' secret."
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
    condition     = output.secrets_lifecycle["green"].end_date == timeadd(output.secrets_lifecycle["green"].start_date, "${var.validity}m")
    error_message = "'green' secret must have a validity of ${var.validity} ${var.unit}."
  }
  assert {
    condition     = output.secrets_lifecycle["green"].start_date == timeadd(output.secrets_lifecycle["blue"].end_date, "-${var.overlap}m")
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

# wait until 'green' is valid. Add 5s to be on the safe side
run "wait_first_overlap" {
  variables {
    create_duration = "${(var.validity - var.overlap) * 60 + 5}s"
  }
  module {
    source = "./tests/wait"
  }
}

run "first_overlap" {
  assert {
    condition     = output.active_secret == "green"
    error_message = "Active secret must have switched 'green'. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].valid && output.secrets_lifecycle["green"].valid
    error_message = "Both secrets must be valid in the overlap phase. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
}

# wait until the first overlap phase is over
run "wait_first_end_blue" {
  variables {
    create_duration = "${var.overlap}m"
  }
  module {
    source = "./tests/wait"
  }
}

run "first_end_blue" {
  assert {
    condition     = output.active_secret == "green"
    error_message = "Active secret must still be 'green'. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
  assert {
    condition     = !output.secrets_lifecycle["blue"].valid && output.secrets_lifecycle["green"].valid
    error_message = "Only 'green' must be valid. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
}

# wait until the second overlap phase where a new blue secret is created and active
run "wait_second_overlap" {
  variables {
    create_duration = "${var.one_valid}m"
  }
  module {
    source = "./tests/wait"
  }
}

run "second_overlap" {
  assert {
    condition     = output.active_secret == "blue"
    error_message = "Active secret must be 'blue' again. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].valid && output.secrets_lifecycle["green"].valid
    error_message = "Both secrets must be valid in the overlap phase. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
  assert {
    # check if secret has been recreated (via start_date) in the last few seconds
    condition     = timecmp(output.secrets_lifecycle["blue"].start_date, timeadd(timestamp(), "-5s")) > 0
    error_message = "'blue' secret must have been recreated. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
}

# wait until 'green' is renewed the first time. Add 5s to be on the safe side
run "wait_first_end_green" {
  variables {
    create_duration = "${var.overlap * 60 + 5}s"
  }
  module {
    source = "./tests/wait"
  }
}

run "first_end_green" {
  assert {
    condition     = output.active_secret == "blue"
    error_message = "Active secret must still be 'blue'. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)},validity_blue_longer_than_green=${local.validity_blue_longer_than_green},secrets_active=${jsonencode(local.secrets_active)}"
  }
  assert {
    condition     = output.secrets_lifecycle["blue"].valid && !output.secrets_lifecycle["green"].valid
    error_message = "Only 'blue' must be valid. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
  assert {
    condition     = timecmp(output.secrets_lifecycle["green"].start_date, timeadd(timestamp(), "-5s")) > 0
    error_message = "'green' secret must have been recreated. Debug: timestamp=${timestamp()}, secrets_lifecycle=${jsonencode(output.secrets_lifecycle)}"
  }
}

locals {
  secrets_lifecycle = {
    "blue" = {
      start_date = local.blue_start_date
      end_date = local.blue_end_date
      rotation_date =local.blue_rotation_date
      valid = local.blue_valid
      key_id = azuread_application_password.blue.key_id
    }
    "green" = {
      start_date = local.green_start_date
      end_date = local.green_end_date
      rotation_date =local.green_rotation_date
      valid = local.green_valid
      key_id = azuread_application_password.green.key_id
    }
  }

  secrects_values = {
    "blue" = {
      value = azuread_application_password.blue.value
    }
    "green" = {
      value = azuread_application_password.green.value
    }
  }

  only_blue_valid = local.blue_valid && !local.green_valid
  only_green_valid = !local.blue_valid && local.green_valid
  both_valid = local.blue_valid && local.green_valid
  validity_blue_longer_than_green = timecmp(local.blue_end_date, local.green_end_date) > 0
   
  # active secret -> valid secret with longest validity
  secrets_active = {
    "blue" = local.only_blue_valid || (local.both_valid && local.validity_blue_longer_than_green)
    "green" = local.only_green_valid || (local.both_valid && !local.validity_blue_longer_than_green)
  }
  active_secret = try([for k, v in local.secrets_active : k if v][0], null)
}


check "valid_secret" {
  assert {
    condition = local.active_secret != null
    error_message = "There must be at least one active secret. Please increase 'jitter' (${var.jitter}) if this issue is reproducible."
  }
}

output "secrets_lifecycle" {
  value = local.secrets_lifecycle
  description = "Map with `start_date`, `end_date`, `rotation_date`, boolean `valid` and `key_id` for both secrets with keys `blue` and `green`."
}

output "secrets_values" {
  value = local.secrects_values
  sensitive = true
  description = "Map with the actual secret values under keys `blue` and `green`."
}

output "active_secret" {
  value = local.active_secret
  description = "Active secret identifier `blue` or `green`."
}

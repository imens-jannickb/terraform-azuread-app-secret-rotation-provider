

locals {
  # factor for months to hours
  M_to_h = 365 / 12 * 24
  units = {
    "minutes" = {
      timeadd_unit   = "m"
      timeadd_factor = 1
    }
    "hours" = {
      timeadd_unit   = "h"
      timeadd_factor = 1
    }
    "months" = {
      timeadd_unit   = "h"
      timeadd_factor = local.M_to_h
    }
  }
}

resource "time_rotating" "blue" {
  # Renew after twice the validity minus the left and right overlap
  rotation_minutes = var.unit == "minutes" ? 2 * (var.validity - var.overlap) : null
  rotation_hours   = var.unit == "hours" ? 2 * (var.validity - var.overlap) : null
  rotation_months  = var.unit == "months" ? 2 * (var.validity - var.overlap) : null

}

resource "time_rotating" "green" {
  # This is the base timestamp to use; essentially, 'overlap' months before end of first time_rotating
  rfc3339          = timeadd(local.blue_end_date, "-${var.overlap * local.units[var.unit].timeadd_factor}${local.units[var.unit].timeadd_unit}")
  rotation_minutes = var.unit == "minutes" ? var.validity : null
  rotation_hours   = var.unit == "hours" ? var.validity : null
  rotation_months  = var.unit == "months" ? var.validity : null

  lifecycle {
    ignore_changes = [rfc3339]
  }
}


locals {
  blue_start_date    = time_rotating.blue.rfc3339
  blue_end_date      = timeadd(time_rotating.blue.rfc3339, "${var.validity * local.units[var.unit].timeadd_factor}${local.units[var.unit].timeadd_unit}")
  blue_rotation_date = time_rotating.blue.rotation_rfc3339
  blue_after_start   = timecmp(timeadd(plantimestamp(), var.jitter), local.blue_start_date) >= 0
  blue_before_end    = timecmp(plantimestamp(), local.blue_end_date) < 0

  green_start_date    = time_rotating.green.rfc3339
  green_end_date      = timeadd(time_rotating.green.rfc3339, "${var.validity * local.units[var.unit].timeadd_factor}${local.units[var.unit].timeadd_unit}")
  green_rotation_date = time_rotating.green.rotation_rfc3339
  green_after_start   = timecmp(timeadd(plantimestamp(), var.jitter), local.green_start_date) >= 0
  green_before_end    = timecmp(plantimestamp(), local.green_end_date) < 0


  blue_valid  = local.blue_after_start && local.blue_before_end
  green_valid = local.green_after_start && local.green_before_end
}

resource "azuread_application_password" "blue" {
  display_name   = "blue;not_before=${formatdate(var.date_format, local.blue_start_date)}"
  application_id = var.application_id

  start_date = local.blue_start_date
  end_date   = local.blue_end_date

  rotate_when_changed = {
    rotation = local.blue_rotation_date
  }
}

resource "azuread_application_password" "green" {
  display_name   = "green;not_before=${formatdate(var.date_format, local.green_start_date)}"
  application_id = var.application_id

  start_date = local.green_start_date
  end_date   = local.green_end_date

  rotate_when_changed = {
    rotation = local.green_rotation_date
  }
}

terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1 "
    }
  }
  required_version = ">= 1.8"
}

resource "time_sleep" "wait" {
  create_duration = var.create_duration

  triggers = {
    current = timestamp()
  }
}

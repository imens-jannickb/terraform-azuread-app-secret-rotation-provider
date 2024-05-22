terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.44.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1 "
    }
  }
  required_version = ">= 1.8"
}

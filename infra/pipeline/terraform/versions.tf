terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws    = ">= 3.27"
    random = ">= 2"
    null   = ">= 2"
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 2.12"
    }
  }
}
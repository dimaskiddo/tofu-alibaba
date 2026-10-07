terraform {
  required_version = ">= 1.10.0, < 1.11.0"

  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.293"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "ACM_CERT_ARN" {
  type    = string
}

variable "ZONE_ID_LIVE" {
  type    = string
}

variable "CERT_ARN" {
  type    = string
}

variable "ZONE_ID_SITE" {
  type    = string
}

variable "FRONTEND_DOMAIN_NAME" {
  type    = string
}

variable "BACKEND_DOMAIN_NAME" {
  type    = string
}

#####################################################################
#
#                           OCEAN
#
#####################################################################

#
# General
#
variable "name" {
  description = ""
  default     = "Tamir Ocean Terraform"
}

variable "controller_id" {
  description = ""
  default     = "fakeClusterId"
}

variable "region" {
  description = ""
  default     = "us-west-2"
}

variable "max_size" {
  description = ""
  default     = 2
}

variable "min_size" {
  description = ""
  default     = 1
}

variable "desired_capacity" {
  description = ""
  default = 2
}

variable "image_id" {
  description = ""
  default = "ami-a27d8fda"
}
terraform {
  required_version = ">= 0.11.0"

//  backend "s3" {
//    # Terraform does not support interpolation on backend object
//    # dynamodb_table = "REPLACE_TF_STATE_DYNAMO_DB_TABLE"
//    bucket         = "REPLACE_TF_STATE_S3_BUCKET"
//    key            = "REPLACE_TF_STATE_KEY.tfstate"
//    region         = "REPLACE_TF_AWS_REGION"
//    profile        = "REPLACE_TF_AWS_PROFILE"
//  }

}
//
//provider "template" {
//  version = "~> 1.0"
//}

provider "spotinst" {
//  version = "~> 0.11"

  # Credentials should be fetched from ENV VARS injected by Jenkins
  token = ""
  account = "act-d8a8bdb6"
}

//provider "aws" {
//  region  = "${var.region}"
//  profile = "REPLACE_TF_AWS_PROFILE"
//}
//
//variable "region" {
//  description = ""
//  default     = "REPLACE_TF_AWS_REGION"
//}
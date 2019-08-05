#####################################################################
#
#                           ELASTIGROUP
#
#####################################################################

#
# General
#
variable "name" {
  description = ""
  default     = "Terraform Elastigroup"
}

variable "description" {
  description = ""
  default     = "created by Terraform Tamir"
}

variable "product" {
  description = ""
  default     = "Linux/UNIX"
}

variable "availability_zones" {
  description = ""
  type        = "list"
  default     = ["us-west-2b", "us-west-2c"]
}

variable "preferred_availability_zones" {
  description = ""
  type        = "list"
  default     = ["us-west-2b"]
}

#
# Subnet IDs
#
variable "region" {
  description = ""
  default     = "us-west-2"
}

variable "subnet_ids" {
  description = ""
  type        = "list"
  default     = []
}

#
# Capacity
#
variable "max_size" {
  description = "The maximum size of the auto scale group."
  default     = 0
}

variable "min_size" {
  description = "The minimum size of the auto scale group."
  default     = 0
}

variable "desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the group."
  default     = 0
}

variable "capacity_unit" {
  description = ""
  default     = "weight"
}

#
# Launch Configuration
#
variable "image_id" {
  description = ""
  default     = "ami-a27d8fda"
}

variable "iam_instance_profile" {
  description = ""
  default     = "iam-profile"
}

variable "key_name" {
  description = ""
  default     = "my-key.ssh"
}

variable "security_groups" {
  description = ""
  type        = "list"
  default     = ["sg-099a3e74"]
}

variable "user_data" {
  description = ""
  default     = "echo hello world"
}

variable "shutdown_script" {
  description = ""
  default     = "echo goodby world"
}

variable "enable_monitoring" {
  description = ""
  default     = false
}

variable "ebs_optimized" {
  description = ""
  default     = false
}

variable "placement_tenancy" {
  description = ""
  default     = "default"
}

#
# Strategy
#
variable "orientation" {
  description = ""
  default     = "balanced" // availability_vs_cost
}

variable "fallback_to_ondemand" {
  description = ""
  default     = false
}

variable "spot_percentage" {
  description = ""
  default     = 100
}

variable "ondemand_count" {
  description = ""
  default     = 1
}

variable "lifetime_period" {
  description = ""
  default     = ""
}

variable "draining_timeout" {
  description = ""
  default     = 50
}

variable "utilize_reserved_instances" {
  description = ""
  default     = false
}

#
# Stateful
#
variable "persist_root_device" {
  description = ""
  default     = false
}

variable "persist_block_devices" {
  description = ""
  default     = false
}

variable "persist_private_ip" {
  description = ""
  default     = false
}

variable "block_devices_mode" {
  description = ""
  default     = "onLaunch"
}

variable "private_ips" {
  description = ""
  type        = "list"
  default     = []
}

variable "stateful_deallocation" {
  description = ""
  type        = "list"
  default     = []
}

#
# Block Devices
#
variable "ebs_block_device" {
  description = ""
  type        = "list"
  default     = []
}

variable "ephemeral_block_device" {
  description = ""
  type        = "list"
  default     = []
}

#
# Network Interface
#
variable "network_interface" {
  description = ""
  type        = "list"
  default     = []
}

#
# Elastic IPs
#
variable "elastic_ips" {
  description = ""
  type        = "list"
  default     = []
}

#
# Instance Types
#
variable "instance_types_ondemand" {
  description = ""
  default     = "m3.2xlarge"
}

variable "instance_types_spot" {
  description = ""
  type        = "list"
  default     = ["m3.xlarge", "m3.2xlarge"]
}

variable "instance_types_preferred_spot" {
  description = ""
  type        = "list"
  default     = ["m3.xlarge"]
}

variable "instance_types_weights" {
  description = ""
  type        = "list"
  default     = [
    {
      instance_type = "c3.large"
      weight        = 10
    },
    {
      instance_type = "c4.xlarge"
      weight        = 16
    }]
}

#
# Health Check
#
variable "health_check_type" {
  description = ""

  // --- HEALTH-CHECKS ---
  // Options:
  //  - "ELB"
  //  - "HCS"
  //  - "TARGET_GROUP"
  //  - "MLB"
  //  - "EC2"
  //  - "MULTAI_TARGET_SET"
  //  - "MLB_RUNTIME"
  //  - "K8S_NODE"
  //  - "NOMAD_NODE"
  //  - "ECS_CLUSTER_INSTANCE"
  default = ""
}

variable "health_check_grace_period" {
  description = ""
  default     = 0 // 100
}

variable "health_check_unhealthy_duration_before_replacement" {
  description = ""
  default     = 0 // 120
}

#
# Scale Up/Down/Target Policies
#
variable "scaling_up_policy" {
  description = ""
  type        = "list"
  default     = []
}

variable "scaling_down_policy" {
  description = ""
  type        = "list"
  default     = []
}

variable "scaling_target_policy" {
  description = ""
  type        = "list"
  default     = []
}

#
# Scheduled Task
#
variable "scheduled_task" {
  description = ""
  type        = "list"
  default     = []
}

#
# Load Balancers
#
variable "elastic_load_balancers" {
  description = ""
  type        = "list"
  default     = []
}

variable "target_group_arns" {
  description = ""
  type        = "list"
  default     = []
}

variable "multai_target_sets" {
  description = ""
  type        = "list"
  default     = []
}

#
# Tags
#
variable "tags" {
  description = ""
  default     = ""
}

#
# Signal
#
variable "signal" {
  description = ""
  type        = "list"
  default     = [{
    name = "INSTANCE_READY_TO_SHUTDOWN" // INSTANCE_READY
    timeout = 100
  }]
}

variable "revert_to_spot" {
  description = ""
  type        = "list"
  default     = []
}

#
# Update Policy
#
variable "update_policy" {
  description = ""
  type        = "list"
  default     = []
}

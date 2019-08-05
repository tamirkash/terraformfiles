#
# Integration: ECS
#
variable "integration_ecs" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Code Deploy
#
variable "integration_codedeploy" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Docker Swarm
#
variable "integration_docker_swarm" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Gitlab
#
variable "integration_gitlab" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Kubernetes
#
variable "integration_kubernetes" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Mesosphere
#
variable "integration_mesosphere" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Multi Runtime
#
variable "integration_multai-runtime" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Nomad
#
variable "integration_nomad" {
  description = ""
  type        = "list"
  default     = []
}

#
# Integration: Rancher
#
variable "integration_rancher" {
  description = ""
  type        = "list"
  default     = []
}

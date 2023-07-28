variable "cpu" {
  description = <<EOS
The hard limit of CPU units to present for the task.
Power of 2 between 256 (.25 vCPU) and 4096 (4 vCPU)
EOS
}
variable "mem" {
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
  description = <<EOS
The hard limit of memory (in MiB) to present to the task.
512, 1024, 2048                              for cpu = 256
1024, 2048, 3072, 4096                       for cpu = 512
Between 2048 and 8192 in increments of 1024  for cpu = 1024
Between 4096 and 16384 in increments of 1024 for cpu = 2048
Between 8192 and 30720 in increments of 1024 for cpu = 4096
EOS
}
variable "service_name" {}
variable "port" {
  default = 0
}
variable "ports" {
  default = []
}
variable "image" {}
variable "vpc_id" {}
variable "platform_version" {
  default     = "LATEST"
  description = "https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html"
}
variable "desired_tasks" {
  default = 1
}
variable "task_role_policies_arn" {
  default = []
  type    = list
}
variable "task_subnets" {}
variable "ecs_cluster_id" {}
variable "additional_security_groups" {
  description = "additional security groups for service"
  default     = []
}
variable "env_vars" {
  default = {}
  type    = map(string)
}
variable "secrets" {
  default = {}
  type    = map(string)
}
variable "command" {
  default = []
}
variable "healthcheck_path" {
  default = "/"
}
variable "healthcheck_interval" {
  default = 30
}
variable "healthcheck_grace_period" {
  default = null
  type    = number
}
variable "healthcheck_timeout" {
  default = 5
}
variable "healthcheck_matcher" {
  default = "200-399"
}
variable "healthcheck_unhealthy_threshold" {
  default = 3
}
variable "enable_local_discovery" {
  default = false
}
variable "local_discovery_service_name" {
  default = ""
}
variable "discovery_namespace_id" {
  default = ""
}
variable "enable_autoscale" {
  default = false
}
variable "autoscale_max_tasks" {
  default = 4
}
variable "autoscale_min_tasks" {
  default = 1
}
variable "autoscale_cpu_target" {
  default = 80
}
variable "tags" {
  default = {}
}
variable "deregistration_delay" {
  description = "load balancer target group deregistration"
  default     = 300
}
variable "docker_ulimits" {
  description = "see https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Ulimit.html"
  default     = []
}

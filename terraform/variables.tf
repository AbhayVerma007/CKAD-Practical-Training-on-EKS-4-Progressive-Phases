variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment (staging/prod)"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be staging or prod."
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "devops-app"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "app_name" {
  description = "Application name for ECR repository"
  type        = string
  default     = "smalllinks"
}

variable "node_group_desired_size" {
  type = number
  default = 2
}

variable "node_group_min_size" {
  type = number
  default = 2
}

variable "node_group_max_size" {
  type = number
  default = 4
}

variable "node_instance_type" {
  type = string
  default = "c7i-flex.large"
}
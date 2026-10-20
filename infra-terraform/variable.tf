variable "aws_region" {
  description = "AWS region where everything is built"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Name prefix used for all resources"
  type        = string
  default     = "amazon-new"
}

variable "environment" {
  description = "Environment name, for example dev or prod"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Tags added to every resource"
  type        = map(string)
  default = {
    Environment = "dev"
    Owner       = "nadeem-khan"
    ManagedBy   = "terraform"
  }
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "learningadmin"
}

variable "db_password" {
  description = "Master password for the database (letters and digits only)"
  type        = string
  sensitive   = true
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "node_instance_types" {
  description = "Server size for the worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "How many worker nodes to start with"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Autoscaling lower limit"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Autoscaling upper limit"
  type        = number
  default     = 3
}
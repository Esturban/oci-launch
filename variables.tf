variable "availability_domain" {
  description = "Availability domain for instance placement"
  type        = string
  default     = "mUFn:CA-TORONTO-1-AD-1"
}

variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
  default     = ""  # Set in .env file for security
}

variable "subnet_id" {
  description = "Subnet OCID"
  type        = string
  default     = ""  # Set in .env file for security
}

variable "instance_shape" {
  description = "Instance shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_name" {
  description = "Instance display name"
  type        = string
  default     = "instance-flexible-deployment"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
  default     = ""  # Will be read from SSH_PUBLIC_KEY_PATH in .env file
}

variable "ocpus" {
  description = "Number of OCPUs for the instance"
  type        = string
  default     = "4"
}

variable "memory_gb" {
  description = "Memory in GB for the instance"
  type        = string
  default     = "24"
} 
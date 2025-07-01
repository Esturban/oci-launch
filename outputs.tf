output "instance_id" {
  description = "OCID of the created instance"
  value       = oci_core_instance.generated_oci_core_instance.id
}

output "instance_state" {
  description = "State of the instance"
  value       = oci_core_instance.generated_oci_core_instance.state
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = oci_core_instance.generated_oci_core_instance.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = oci_core_instance.generated_oci_core_instance.private_ip
}

output "instance_name" {
  description = "Display name of the instance"
  value       = oci_core_instance.generated_oci_core_instance.display_name
}

output "availability_domain" {
  description = "Availability domain where instance was created"
  value       = oci_core_instance.generated_oci_core_instance.availability_domain
} 
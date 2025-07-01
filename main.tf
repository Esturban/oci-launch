provider "oci" {}

# Get the latest Ubuntu image
data "oci_core_images" "ubuntu_images" {
	compartment_id = var.compartment_id
	operating_system = "Canonical Ubuntu"
	operating_system_version = "22.04"
	shape = var.instance_shape
	state = "AVAILABLE"
	sort_by = "TIMECREATED"
	sort_order = "DESC"
}

resource "oci_core_instance" "generated_oci_core_instance" {
	agent_config {
		is_management_disabled = "false"
		is_monitoring_disabled = "false"
		plugins_config {
			desired_state = "DISABLED"
			name = "Vulnerability Scanning"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Oracle Java Management Service"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "OS Management Service Agent"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "OS Management Hub Agent"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Management Agent"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Fleet Application Management Service"
		}
		plugins_config {
			desired_state = "ENABLED"
			name = "Custom Logs Monitoring"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Compute RDMA GPU Monitoring"
		}
		plugins_config {
			desired_state = "ENABLED"
			name = "Compute Instance Run Command"
		}
		plugins_config {
			desired_state = "ENABLED"
			name = "Compute Instance Monitoring"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Compute HPC RDMA Auto-Configuration"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Compute HPC RDMA Authentication"
		}
		plugins_config {
			desired_state = "ENABLED"
			name = "Cloud Guard Workload Protection"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Block Volume Management"
		}
		plugins_config {
			desired_state = "DISABLED"
			name = "Bastion"
		}
	}
	availability_config {
		recovery_action = "RESTORE_INSTANCE"
	}
	availability_domain = var.availability_domain
	compartment_id = var.compartment_id
	create_vnic_details {
		assign_ipv6ip = "false"
		assign_private_dns_record = "true"
		assign_public_ip = "true"
		subnet_id = var.subnet_id
	}
	display_name = var.instance_name
	instance_options {
		are_legacy_imds_endpoints_disabled = "false"
	}
	is_pv_encryption_in_transit_enabled = "true"
	metadata = {
		"ssh_authorized_keys" = var.ssh_public_key
	}
	shape = var.instance_shape
	shape_config {
		memory_in_gbs = var.memory_gb
		ocpus = var.ocpus
	}
	source_details {
		boot_volume_size_in_gbs = "50"
		boot_volume_vpus_per_gb = "10"
		source_id = data.oci_core_images.ubuntu_images.images[0].id
		source_type = "image"
	}
}

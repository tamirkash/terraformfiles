#####################################################################
#
#                           ELASTIGROUP
#
#####################################################################
resource "spotinst_elastigroup_aws" "v2" {

  name                         = "${var.name}"
  description                  = "${var.description}"
  product                      = "${var.product}"
  availability_zones           = "${var.availability_zones}"
  preferred_availability_zones = "${var.preferred_availability_zones}"

  // --- SUBNET IDS ---
  region      = "${var.region}"
  // subnet_ids  = "${var.subnet_ids}" // conflicts with availability_zones

  // --- CAPACITY ---
  max_size         = "${var.max_size}"
  min_size         = "${var.min_size}"
  desired_capacity = "${var.desired_capacity}"
  capacity_unit    = "${var.capacity_unit}"

  // --- LAUNCH CONFIGURATION ---
  image_id             = "${var.image_id}"
  iam_instance_profile = "${var.iam_instance_profile}"
  key_name             = "${var.key_name}"
  security_groups      = "${var.security_groups}"
  user_data            = "${var.user_data}"
  shutdown_script      = "${var.shutdown_script}"
  enable_monitoring    = "${var.enable_monitoring}"
  ebs_optimized        = "${var.ebs_optimized}"
  placement_tenancy    = "${var.placement_tenancy}"

  // --- STRATEGY ---
  orientation                = "${var.orientation}"
  fallback_to_ondemand       = "${var.fallback_to_ondemand}"
  spot_percentage            = "${var.spot_percentage}"
  // ondemand_count             = "${var.ondemand_count}" // conflicts with spot_percentage
  lifetime_period            = "${var.lifetime_period}"
  draining_timeout           = "${var.draining_timeout}"
  utilize_reserved_instances = "${var.utilize_reserved_instances}"

  // -- STATEFUL --
  persist_root_device   = "${var.persist_root_device}"
  persist_block_devices = "${var.persist_block_devices}"
  persist_private_ip    = "${var.persist_private_ip}"
  block_devices_mode    = "${var.block_devices_mode}"
  private_ips           = "${var.private_ips}"
  stateful_deallocation = "${var.stateful_deallocation}"

  // --- BLOCK DEVICES ---
  ebs_block_device       = "${var.ebs_block_device}"
  ephemeral_block_device = "${var.ephemeral_block_device}"

  // --- NETWORK INTERFACE ---
  network_interface = "${var.network_interface}"

  // --- ELASTIC IPs ---
  elastic_ips = "${var.elastic_ips}"

  // --- INSTANCE TYPES ---
  instance_types_ondemand       = "${var.instance_types_ondemand}"
  instance_types_spot           = "${var.instance_types_spot}"
  instance_types_preferred_spot = "${var.instance_types_preferred_spot}"
  instance_types_weights        = "${var.instance_types_weights}"

  // --- HEALTH CHECK ---
  health_check_type                                  = "${var.health_check_type}"
  health_check_grace_period                          = "${var.health_check_grace_period}"
  health_check_unhealthy_duration_before_replacement = "${var.health_check_unhealthy_duration_before_replacement}"

  // --- SCALE UP/DOWN/TARGET POLICIES ---
  scaling_up_policy     = "${var.scaling_up_policy}"
  scaling_down_policy   = "${var.scaling_down_policy}"
  scaling_target_policy = "${var.scaling_target_policy}"

  // --- SCHEDULED TASK ---
  scheduled_task = "${var.scheduled_task}"

  // --- LOAD BALANCERS ---
  elastic_load_balancers = "${var.elastic_load_balancers}"
  target_group_arns      = "${var.target_group_arns}"
  multai_target_sets     = "${var.multai_target_sets}"

  // --- INTEGRATION: ECS ---
  integration_ecs = "${var.integration_ecs}"

  // --- INTEGRATION: CODE DEPLOY ---
  integration_codedeploy = "${var.integration_codedeploy}"

  // --- INTEGRATION: DOCKER SWARM ---
  integration_docker_swarm = "${var.integration_docker_swarm}"

  // --- INTEGRATION: GITLAB ---
  integration_gitlab = "${var.integration_gitlab}"

  // --- INTEGRATION: KUBERNETES ---
  integration_kubernetes = "${var.integration_kubernetes}"

  // --- INTEGRATION: MESOSPHERE ---
  integration_mesosphere = "${var.integration_mesosphere}"

  // --- TAGS ---
  tags = [{
      key   = "Name"
      value = "spot-elastigroup-tf-provider-v2"
    },
    {
      key   = "Service"
      value = "spot-elastigroup-tf-provider-v2"
    },
    {
      key   = "Creator"
      value = "terraform@spotinst.com"
    },
    {
      key   = "Product"
      value = "elastigroup"
    }
  ]

  // -- UPDATE POLICY --
  update_policy = "${var.update_policy}"

  // --- SIGNAL ---
  signal = "${var.signal}"

  lifecycle = {
    ignore_changes = [
      "desired_capacity"
    ]
  }
}
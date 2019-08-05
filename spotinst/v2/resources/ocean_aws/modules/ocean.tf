#####################################################################
#
#                           OCEAN
#
#####################################################################

resource "spotinst_ocean_aws" "v2" {
  name = "${var.name}"
  controller_id = "${var.controller_id}"
  region = "${var.region}"

  max_size = "${var.max_size}"
  min_size = "${var.min_size}"
  desired_capacity = "${var.desired_capacity}"

  subnet_ids = [
    "subnet-79da021e"]

  whitelist = [
    "t2.micro",
    "m1.small"]

  image_id = "${var.image_id}"
  security_groups = [
    "sg-0195f2ac3a6014a15"]

  //  key_name = ""
  user_data = "echo hello world"
  //  iam_instance_profile = "iam-profile"
  root_volume_size = 20

  associate_public_ip_address = true

  //  load_balancers = [
  //    {
  //      arn = "arn:aws:elasticloadbalancing:us-west-2:fake-arn"
  //      type = "TARGET_GROUP"
  //    },
  //    {
  //      name = "AntonK"
  //      type = "CLASSIC"
  //    }
  //  ]

  fallback_to_ondemand = true
  spot_percentage = 100
  utilize_reserved_instances = false

  autoscaler = {
    autoscale_is_enabled = false
    autoscale_is_auto_config = false
    autoscale_cooldown = 300

    autoscale_headroom = {
      cpu_per_unit = 1024
      gpu_per_unit = 1
      memory_per_unit = 512
      num_of_units = 2
    }

    autoscale_down = {
      evaluation_periods = 300
    }

    resource_limits = {
      max_vcpu = 1024
      max_memory_gib = 20
    }
  }
}


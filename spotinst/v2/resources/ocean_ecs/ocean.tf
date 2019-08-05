resource "spotinst_ocean_ecs" "v2" {
  region = "us-west-2"
  name = "terraform-ecs-cluster"
//  cluster_name = "orfromEnvironment_Batch_852a670a-aa73-3d5d-9576-147a26d43401"
  cluster_name = "terraform-ecs-cluster"

  min_size         = "0"
  max_size         = "1"
  desired_capacity = "0"

//  autoscaler = {
//    cooldown = 180
//    headroom = {
//      cpu_per_unit = 1024
//      memory_per_unit = 512
//      num_of_units = 3
//    }
//    down = {
//      max_scale_down_percentage = 10
//      evaluation_periods = 3
//    }
//    is_auto_config = true
//    is_enabled = true
//    resource_limits = {
//      max_vcpu = 2
//      max_memory_gib = 1
//    }
//  }

  autoscaler = {
    cooldown = 240
    headroom = {
      cpu_per_unit = 512
      memory_per_unit = 1024
      num_of_units = 1
    }
    down = {
      max_scale_down_percentage = 20
      evaluation_periods = 5
    }
    is_auto_config = false
    is_enabled = false
    resource_limits = {
      max_vcpu = 1
      max_memory_gib = 2
    }
  }

  //region compute
  subnet_ids = ["subnet-79da021e"]
  whitelist = ["t3.medium"]

  //region launch spec
  security_group_ids = ["sg-0a8e7b3cd1cfd3d6f"]
  image_id = "ami-082b5a644766e0e6f"
  iam_instance_profile = "arn:aws:iam::842422002533:instance-profile/ecsInstanceRole"

  key_pair = "TamirKeyPair"
  user_data = "IyEvYmluL2Jhc2gKZWNobyBFQ1NfQ0xVU1RFUj1vcmZyb21FbnZpcm9ubWVudF9CYXRjaF84NTJhNjcwYS1hYTczLTNkNWQtOTU3Ni0xNDdhMjZkNDM0MDEgPj4gL2V0Yy9lY3MvZWNzLmNvbmZpZw=="
  associate_public_ip_address = false
  //endregion
  //endregion

  update_policy = {
    should_roll = true
    roll_config = {
      batch_size_percentage = 100
    }
  }
}
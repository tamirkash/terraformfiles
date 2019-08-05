resource "spotinst_ocean_ecs_launch_spec" "v2" {
  name = "terraform-ecs-launch-spec"
  ocean_id = "o-92189543"
  image_id = "ami-082b5a644766e0e6f"
  user_data = "IyEvYmluL2Jhc2gKZWNobyBFQ1NfQ0xVU1RFUj1vcmZyb21FbnZpcm9ubWVudF9CYXRjaF84NTJhNjcwYS1hYTczLTNkNWQtOTU3Ni0xNDdhMjZkNDM0MDEgPj4gL2V0Yy9lY3MvZWNzLmNvbmZpZw=="
//  security_group_ids = ["awseb-e-sznmxim22e-stack-AWSEBSecurityGroup-10FZKNGB09G1W"]
  iam_instance_profile = "ecsInstanceRole"
  attributes = [
    {
      key = "key"
      value = "value"
    },
    {
      key = "key2"
      value = "value2"
    }
  ]
}
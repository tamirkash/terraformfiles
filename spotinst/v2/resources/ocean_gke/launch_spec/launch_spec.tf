resource "spotinst_ocean_gke_launch_spec" "v2" {
  ocean_id     = "o-978b0eef"
  source_image = "fake"

  metadata = [
    {
      key = "gci-update-strategy"
      value = "update_disabled"
    },
    {
      key = "gci-ensure-gke-docker"
      value = "true"
    },
//    {
//      key = "kube-labels"
//      value = ""
//    },
//    {
//      key = "google-compute-enable-pcid"
//      value = "true"
//    },
//    {
//      key = "enable-oslogin"
//      value = "false"
//    },
//    {
//      key = "cluster-name"
//      value = "gke-demo"
//    },
//    {
//      key = "cluster-location"
//      value = "us-central1-a"
//    }
  ]

  labels = [
    {
      key = "testKey"
      value = "testVal"
    },
    {
      key = "testKey2"
      value = "testVal2"
    }
  ]

  taints = [
    {
      key = "testTaintKey"
      value = "testTaintVal"
      effect = "NoSchedule"
    },
    {
      key = "testTaintKey2"
      value = "testTaintVal2"
      effect = "NoSchedule"
    }
  ]
}
resource "spotinst_ocean_gke_import" "ocean-importer-01" {
  // Mandatory
  cluster_name = "terraform-acc-tests-do-not-delete"
  location     = "us-central1-a"
  whitelist = [
    "n1-standard-1",
    "n1-standard-2"]
  // Optional
  backend_services = [{
    service_name = "terraform-acc-test-backend-service"
    location_type = "global"
    scheme = ""
    named_ports = [{
      name = "https"
      ports = [
        80,
        8080]
    }]
  }]
}
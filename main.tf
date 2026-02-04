terraform {
  # 1. Store the "State" in the cloud so GitHub Actions doesn't get confused
  # CRITICAL: You must create this bucket once: 
  # gcloud storage buckets create gs://panos-tf-state --project=panos-jupyter --location=us-east1 --uniform-bucket-level-access
  backend "gcs" {
    bucket  = "panos-tf-state"
    prefix  = "workstation/state"
  }

  required_providers {
    google = {
      source = "hashicorp/google"
    }
    google-beta = {
      source = "hashicorp/google-beta"
    }
  }
}

provider "google" {
  project = "panos-jupyter"
  region  = "us-east1"
  zone    = "us-east1-b"
}

provider "google-beta" {
  project = "panos-jupyter"
  region  = "us-east1"
  zone    = "us-east1-b"
}

# 2. Enable Required APIs automatically
resource "google_project_service" "workstations" {
  provider           = google-beta
  service            = "workstations.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_resource_manager" {
  provider           = google-beta
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

# 3. The Workstation Cluster (The Control Plane)
resource "google_workstations_workstation_cluster" "default" {
  provider               = google-beta
  workstation_cluster_id = "panos-dev-cluster"
  
  # Network paths MUST be fully specified for this API
  network    = "projects/panos-jupyter/global/networks/default"
  subnetwork = "projects/panos-jupyter/regions/us-east1/subnetworks/default"
  location   = "us-east1"
  
  depends_on = [google_project_service.workstations, google_project_service.cloud_resource_manager]
}

# 4. The Workstation Configuration (The Template)
resource "google_workstations_workstation_config" "default" {
  provider               = google-beta
  workstation_config_id  = "panos-pycharm-config"
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location               = "us-east1"

  host {
    gce_instance {
      machine_type                = "e2-standard-4" # 4 vCPUs, 16GB RAM
      boot_disk_size_gb           = 100
      disable_public_ip_addresses = false 
      
      # Identity: Allows pulling private images & accessing Google Cloud APIs
      service_account = "run-jupyter-vm@panos-jupyter.iam.gserviceaccount.com"
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }

  container {
    image       = "us-east1-docker.pkg.dev/panos-jupyter/ipeirotis/dealing-with-data:latest"
    run_as_user = 1000 
    
    # VS Code specific: The 'user' home directory in Google's base image
    working_dir = "/home/user"
  }

  persistent_directories {
    # This must be exactly '/home'. It mounts a disk over the container's home folder.
    mount_path = "/home"
    
    gce_pd {
      size_gb        = 200
      fs_type        = "ext4"
      disk_type      = "pd-balanced"
      reclaim_policy = "RETAIN" # Saves your data even if you destroy the workstation
    }
  }

  # Auto-Sleep Settings (Cost Savings)
  idle_timeout    = "7200s"  # Shutdown after 2 hours of inactivity
  running_timeout = "43200s" # Forced shutdown after 12 hours
}

# 5. The Workstation Instance (Your Machine)
resource "google_workstations_workstation" "default" {
  provider               = google-beta
  workstation_id         = "panos-dev-machine"
  workstation_config_id  = google_workstations_workstation_config.default.workstation_config_id
  workstation_cluster_id = google_workstations_workstation_cluster.default.workstation_cluster_id
  location               = "us-east1"
}

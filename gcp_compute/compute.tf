provider "google" {
  credentials = file("~/Downloads/potent-density-316210-305902d69267.json")
  project = "potent-density-316210"
  region = "europe-north1"
}

resource "random_id" "instance_id" {
  byte_length = 16
}

resource "google_compute_instance" "zlogene_instance" {
  name = "zlogene-vm-${random_id.instance_id.hex}"
  machine_type = "f1-micro"
  zone = "europe-north1-a"

  # gcloud compute images list
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2104-hirsute-v20210511a"
    }
  }

  network_interface {
    network = "default"
  access_config {
  }
}

metadata = {
   ssh-keys = "zlogene:${file("/home/zlogene/ssh.pub")}"
 }

 metadata_startup_script = "apt-get update"
}

resource "google_compute_firewall" "my_rules" {
  name = "zlogene-ssh"
  network = "default"
  
allow {
    protocol = "tcp"
    ports = ["22"]
  }

allow {
  protocol = "icmp"
}
}

output "ip" {
 value = google_compute_instance.zlogene_instance.network_interface.0.access_config.0.nat_ip
}

# cmd: terraform output ip

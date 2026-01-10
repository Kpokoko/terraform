resource "yandex_compute_instance_group" "servers_pool" {
  name = "servers-pool"
  service_account_id = "ajejvmddjg0sn6b23hvb"

  allocation_policy {
    zones = ["ru-central1-b"]
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  deploy_policy {
    max_creating     = 3
    max_unavailable  = 3
    max_expansion    = 0
  }

  application_load_balancer {
    target_group_name = "servers-pool-tg"
  }

  instance_template {
    platform_id = "standard-v2"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      initialize_params {
        image_id = var.server_iso_id
        size     = 20
      }
    }

    network_interface {
      subnet_ids = ["e2l7o2gdb69oejco9dcl"]
      nat       = true
      security_group_ids = [
        yandex_vpc_security_group.vm_sg.id
      ]
    }

    metadata = {
      ssh-keys = "test:${file("pubkey.txt")}"
      user-data = <<EOT
  #cloud-config
  users:
    - name: test
      sudo: ALL=(ALL) NOPASSWD:ALL
      groups: users, admin
      home: /home/test
      shell: /bin/bash
      lock_passwd: false
      ssh_authorized_keys:
        - ${file("pubkey.txt")}

  bootcmd:
    - mkdir -p /home/test/back
    - mkdir -p /home/test/certs

  write_files:
    - path: /home/test/start_back.sh
      owner: test:test
      permissions: '0755'
      defer: true
      content: |
        #!/bin/bash
        cd /home/test/back
        if [ ! -d venv ]; then
          python3 -m venv venv
        fi
        . venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        nohup uvicorn app.app:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 &

    - path: /home/test/certs/server.certs
      owner: test:test
      permissions: '0644'
      source: "server.crt"

    - path: /home/test/certs/server.key
      owner: test:test
      permissions: '0600'
      source: "server.key"

  runcmd:
    - apt update
    - apt install -y python3.12-venv python3-pip git
    - git clone "${var.git_url}" /home/test/back
    - chown -R test:test /home/test
    - [chmod, -R, u+rwX, /home/test/back]
    - /home/test/start_back.sh
  EOT
    }
  }

  health_check {
    http_options {
      port = 8000
      path = "/"
    }
  }
}

resource "yandex_vpc_security_group" "vm_sg" {
  name       = "backend_security_group"
  network_id = "enp3dh4te1pejmr538gp"

  ingress {
    protocol       = "TCP"
    port           = 443
    # только от ALB или всех, если тест
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
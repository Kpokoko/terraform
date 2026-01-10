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
        cat > /etc/nginx/sites-available/app <<EOL
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /home/test/certs/server.crt;
    ssl_certificate_key /home/test/certs/server.key;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL
        ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        nohup uvicorn app.app:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 &

  runcmd:
    - apt update
    - apt install -y python3.12-venv python3-pip git nginx
    - git clone "${var.git_url}" /home/test/back
    - chown -R test:test /home/test
    - curl -o /home/test/certs/server.crt https://storage.yandexcloud.net/dungeon-certs/server.crt
    - curl -o /home/test/certs/server.key https://storage.yandexcloud.net/dungeon-certs/server.key
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
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
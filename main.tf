resource "yandex_compute_instance" "server1" {
  name = "server2"
  zone = "ru-central1-b"

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
    subnet_id = "e2l7o2gdb69oejco9dcl"
    nat       = true
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

runcmd:
  - apt update
  - apt install -y python3.12-venv python3-pip git
  - git clone "${var.git_url}" /home/test/back
  - chown -R test:test /home/test
  - [chmod, -R, u+rwX, /home/test/back]
  - bash -c "if [ -f /home/test/back/.env ]; then sed -i '1c\\DATABASE_URL=postgresql+asyncpg://${var.db_user}:${var.db_password}@localhost:5432/react' /home/test/app/.env; fi"
  - /home/test/start_back.sh
EOT
  }
}
resource "yandex_compute_instance" "server1" {
  name = "server1"
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
    subnet_id = "e2lp24vhi1c7o4evfo7s"
    nat       = true
  }

  metadata = {
    ssh-keys = "test:${file("../pubkey.txt")}"
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
      - ${file("../pubkey.txt")}

bootcmd:
  - mkdir -p /home/test/app
  - chown test:test /home/test/app

write_files:
  - path: /home/test/start_server.sh
    owner: test:test
    permissions: '0755'
    content: |
      #!/bin/bash
      cd /home/test/app
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
  - git clone "${var.git_url}" /home/test/app
  - [chown, -R, test:test, /home/test/app]
  - [chmod, -R, u+rwX, /home/test/app]
  - bash -c "if [ -f /home/test/app/.env ]; then sed -i '1c\\DATABASE_URL=postgresql+asyncpg://${var.db_user}:${var.db_password}@localhost:5432/react' /home/test/app/.env; fi"
  - /home/test/start_server.sh
EOT
  }
}
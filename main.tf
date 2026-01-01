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
    subnet_id = "e2lp24vhi1c7o4evfo7s"
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
  - mkdir -p /home/test/back /home/test/front

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
  - path: /etc/systemd/system/front.service
    owner: root:root
    permissions: '0644'
    content: |
      [Unit]
      Description=Frontend
      
      [Service]
      User=test
      Group=test
      WorkingDirectory=/home/test/front
      Environment="NVM_DIR=/home/test/.nvm"
      Environment="CI=true"
      ExecStart=/home/test/start_vite.sh
      Restart=always
      RestartSec=5
      StandardOutput=append:/home/test/front/front.log
      StandardError=append:/home/test/front/front.err.log

      [Install]
      WantedBy=multi-user.target
  - path: /home/test/setup_front.sh
    owner: test:test
    permissions: '0755'
    defer: true
    content: |
      #!/bin/bash
      systemctl daemon-reload
      systemctl enable front.service
      systemctl start front.service
  - path: /home/test/start_vite.sh
    owner: test:test
    permissions: '0755'
    defer: true
    content: |
      #!/bin/bash
      cd /home/test/front
      export NVM_DIR="/home/test/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      nvm use 24
      exec npm run dev

runcmd:
  - apt update
  - apt install -y python3.12-venv python3-pip git
  - git clone "${var.git_url}" /home/test/back
  - git clone https://github.com/Kpokoko/react-ts-app /home/test/front
  - chown -R test:test /home/test
  - [chmod, -R, u+rwX, /home/test/back]
  - bash -c "if [ -f /home/test/back/.env ]; then sed -i '1c\\DATABASE_URL=postgresql+asyncpg://${var.db_user}:${var.db_password}@localhost:5432/react' /home/test/app/.env; fi"
  - /home/test/start_back.sh
  - su - test -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
  - su - test -c "cd /home/test/front && . /home/test/.nvm/nvm.sh && nvm install 24"
  - su - test -c "cd /home/test/front && . /home/test/.nvm/nvm.sh && nvm use 24 && npm install"
  - /home/test/setup_front.sh
EOT
  }
}
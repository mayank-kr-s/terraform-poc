# Ansible Beginner Guide — Configuration Management

> **Goal**: Learn Ansible from scratch to automate EC2 server setup, Nginx config, and security hardening.

---

## 1. What is Ansible?

Ansible is a tool that **configures servers automatically** — install software, copy files, manage services, etc.

```
You write playbooks (YAML files) → Ansible SSHes into servers → Runs the tasks
```

**Why Ansible?**
- **Agentless**: No software to install on servers — just SSH.
- **Idempotent**: Run it 10 times, same result. It only changes what's needed.
- **Human Readable**: YAML files are easy to read and write.

### Terraform vs Ansible
| | Terraform | Ansible |
|---|-----------|---------|
| **Purpose** | Create infrastructure (VPC, EC2, ALB) | Configure servers (install software, copy files) |
| **Approach** | Declarative (I want 2 servers) | Procedural (Step 1, Step 2, Step 3) |
| **State** | Maintains state file | Stateless |
| **When** | First — create the servers | Second — configure them |

```
Terraform creates EC2 instances → Ansible configures them
```

---

## 2. Install Ansible

### Windows (via WSL — Windows Subsystem for Linux)
Ansible doesn't run natively on Windows. Use WSL:
```powershell
# Enable WSL (run as admin in PowerShell)
wsl --install

# After restart, open Ubuntu from Start Menu, then:
sudo apt update
sudo apt install -y ansible python3-pip
```

### macOS
```bash
brew install ansible
```

### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y ansible
```

### Alternative: Use Ansible from your EC2 bastion host
You can also install Ansible on a `t2.micro` bastion server and run it from there.

### Verify
```bash
ansible --version
# ansible [core 2.16.x]
```

---

## 3. Core Concepts

### 3.1 Inventory
A list of servers Ansible should manage.

```ini
# inventory/hosts.ini

[webservers]
10.0.1.10 ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/my-key.pem
10.0.1.11 ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/my-key.pem

[loadbalancer]
10.0.0.5 ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/my-key.pem
```

**Dynamic Inventory** (better for AWS): Automatically discovers EC2 instances by tags.

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: dev
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
```

### 3.2 Playbook
A YAML file that describes **what to do** on your servers.

```yaml
# playbook.yml
---
- name: Configure web servers
  hosts: webservers              # Which servers from inventory
  become: yes                     # Run as root (sudo)

  tasks:
    - name: Update all packages
      yum:
        name: "*"
        state: latest

    - name: Install Nginx
      yum:
        name: nginx
        state: present

    - name: Start Nginx service
      service:
        name: nginx
        state: started
        enabled: yes
```

### 3.3 Tasks
A single action — install a package, copy a file, restart a service.

```yaml
tasks:
  # Install a package
  - name: Install Nginx
    yum:
      name: nginx
      state: present

  # Copy a file
  - name: Copy Nginx config
    copy:
      src: files/nginx.conf
      dest: /etc/nginx/nginx.conf
    notify: Restart Nginx     # Trigger handler if file changed

  # Run a command
  - name: Check disk space
    command: df -h
    register: disk_output     # Save output to variable

  - name: Print disk space
    debug:
      var: disk_output.stdout
```

### 3.4 Handlers
Tasks that only run **when notified** (e.g., restart Nginx only if config changed).

```yaml
handlers:
  - name: Restart Nginx
    service:
      name: nginx
      state: restarted
```

### 3.5 Roles
A way to organize playbooks into reusable packages.

```
roles/
├── nginx/
│   ├── tasks/
│   │   └── main.yml         # Tasks to execute
│   ├── handlers/
│   │   └── main.yml         # Handlers
│   ├── templates/
│   │   └── nginx.conf.j2    # Jinja2 templates
│   ├── files/
│   │   └── index.html       # Static files
│   └── defaults/
│       └── main.yml         # Default variables
├── security/
│   ├── tasks/
│   │   └── main.yml
│   └── defaults/
│       └── main.yml
```

### 3.6 Templates (Jinja2)
Dynamic configuration files with variables.

```nginx
# templates/nginx.conf.j2
server {
    listen {{ nginx_port | default(80) }};
    server_name {{ server_name }};

    location / {
        proxy_pass http://{{ app_backend }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```yaml
# In playbook — variables get substituted
vars:
  nginx_port: 80
  server_name: myapp.example.com
  app_backend: "127.0.0.1:8080"
```

---

## 4. Running Ansible

### Ad-Hoc Commands (One-Off Tasks)
```bash
# Ping all servers
ansible all -i inventory/hosts.ini -m ping

# Run a command on all webservers
ansible webservers -i inventory/hosts.ini -m command -a "uptime"

# Install a package
ansible webservers -i inventory/hosts.ini -m yum -a "name=nginx state=present" --become
```

### Running Playbooks
```bash
# Run a playbook
ansible-playbook -i inventory/hosts.ini playbook.yml

# Dry run (check mode — shows what WOULD change)
ansible-playbook -i inventory/hosts.ini playbook.yml --check

# Verbose output (for debugging)
ansible-playbook -i inventory/hosts.ini playbook.yml -vvv

# Limit to specific hosts
ansible-playbook -i inventory/hosts.ini playbook.yml --limit "10.0.1.10"
```

---

## 5. Key Ansible Modules (Cheat Sheet)

### Package Management
```yaml
# Install (Amazon Linux / CentOS)
- name: Install packages
  yum:
    name:
      - nginx
      - git
      - python3
    state: present

# Install (Ubuntu/Debian)
- name: Install packages
  apt:
    name:
      - nginx
      - git
    state: present
    update_cache: yes
```

### File Management
```yaml
# Copy a file
- name: Copy config
  copy:
    src: files/app.conf
    dest: /etc/app/app.conf
    owner: root
    group: root
    mode: "0644"

# Create a directory
- name: Create app directory
  file:
    path: /opt/myapp
    state: directory
    mode: "0755"

# Template (with variables)
- name: Deploy Nginx config
  template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/conf.d/default.conf
  notify: Restart Nginx
```

### Service Management
```yaml
- name: Start and enable Nginx
  service:
    name: nginx
    state: started
    enabled: yes     # Start on boot
```

### User Management
```yaml
- name: Create app user
  user:
    name: appuser
    shell: /bin/bash
    groups: wheel
    append: yes
```

### Firewall (firewalld)
```yaml
- name: Allow HTTP traffic
  firewalld:
    service: http
    permanent: yes
    state: enabled
    immediate: yes
```

### System Settings
```yaml
# Set sysctl parameters
- name: Harden network settings
  sysctl:
    name: net.ipv4.ip_forward
    value: "0"
    state: present
    reload: yes

# Set file limits
- name: Set file descriptor limits
  lineinfile:
    path: /etc/security/limits.conf
    line: "* soft nofile 65535"
```

---

## 6. Example: Complete Playbook for This Project

```yaml
---
# site.yml - Main playbook
- name: Configure EC2 web servers
  hosts: webservers
  become: yes
  vars:
    app_port: 8080
    nginx_port: 80

  tasks:
    # ── System Updates ──
    - name: Update all packages
      yum:
        name: "*"
        state: latest

    # ── Install Software ──
    - name: Install required packages
      yum:
        name:
          - nginx
          - python3
          - git
          - fail2ban
        state: present

    # ── Deploy Application ──
    - name: Create app directory
      file:
        path: /opt/webapp
        state: directory
        mode: "0755"

    - name: Deploy index.html
      copy:
        content: |
          <!DOCTYPE html>
          <html>
          <head><title>Hello from {{ inventory_hostname }}</title></head>
          <body>
            <h1>Server: {{ inventory_hostname }}</h1>
            <p>Deployed by Ansible</p>
          </body>
          </html>
        dest: /opt/webapp/index.html

    # ── Configure Nginx Reverse Proxy ──
    - name: Deploy Nginx config
      template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/conf.d/default.conf
      notify: Restart Nginx

    - name: Remove default Nginx page
      file:
        path: /usr/share/nginx/html/index.html
        state: absent

    # ── Security Hardening ──
    - name: Disable root SSH login
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "^PermitRootLogin"
        line: "PermitRootLogin no"
      notify: Restart SSH

    - name: Disable password authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: "^PasswordAuthentication"
        line: "PasswordAuthentication no"
      notify: Restart SSH

    # ── Start Services ──
    - name: Start Nginx
      service:
        name: nginx
        state: started
        enabled: yes

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted

    - name: Restart SSH
      service:
        name: sshd
        state: restarted
```

---

## 7. Ansible + Terraform Integration

Terraform creates EC2 → Outputs the IPs → Ansible uses them.

### Method 1: Generate Inventory from Terraform Output
```bash
# After terraform apply, get IPs
terraform output -json ec2_private_ips

# Generate inventory file
echo "[webservers]" > inventory/hosts.ini
terraform output -json ec2_private_ips | jq -r '.[]' | while read ip; do
  echo "$ip ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/my-key.pem" >> inventory/hosts.ini
done
```

### Method 2: Use Terraform `local-exec` Provisioner
```hcl
resource "null_resource" "ansible" {
  depends_on = [aws_instance.web]

  provisioner "local-exec" {
    command = "ansible-playbook -i '${aws_instance.web.public_ip},' playbook.yml"
  }
}
```

### Method 3: AWS Dynamic Inventory (Best)
```bash
# Install AWS collection
ansible-galaxy collection install amazon.aws

# Use aws_ec2 plugin — auto-discovers instances by tags
ansible-playbook -i inventory/aws_ec2.yml site.yml
```

---

## 8. Debugging Ansible

```bash
# Check syntax
ansible-playbook playbook.yml --syntax-check

# Dry run
ansible-playbook -i inventory/hosts.ini playbook.yml --check

# Step through tasks one by one
ansible-playbook -i inventory/hosts.ini playbook.yml --step

# Verbose mode (more v = more detail)
ansible-playbook -i inventory/hosts.ini playbook.yml -v    # basic
ansible-playbook -i inventory/hosts.ini playbook.yml -vvv  # detailed
ansible-playbook -i inventory/hosts.ini playbook.yml -vvvv # connection debug

# Debug a variable
- name: Show variable value
  debug:
    var: my_variable

- name: Show message
  debug:
    msg: "The server IP is {{ ansible_default_ipv4.address }}"
```

---

## 9. Common Mistakes & Fixes

| Mistake | Fix |
|---------|-----|
| `Permission denied (publickey)` | Check SSH key path and permissions (`chmod 400 key.pem`) |
| `UNREACHABLE! => Failed to connect` | Check security group allows SSH (port 22) from your IP |
| YAML indentation error | Use 2 spaces, never tabs. Use a YAML linter. |
| `sudo: a password is required` | Add `become: yes` and ensure the user has sudo rights |
| Module not found | Install collection: `ansible-galaxy collection install amazon.aws` |
| Changes not applied | Check `--check` mode isn't accidentally on |

---

## 10. Ansible Directory Structure for This Project

```
ansible/
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Main playbook (entry point)
├── inventory/
│   ├── hosts.ini            # Static inventory
│   └── aws_ec2.yml          # Dynamic AWS inventory
├── roles/
│   ├── common/              # Common setup (updates, basic packages)
│   │   └── tasks/
│   │       └── main.yml
│   ├── nginx/               # Nginx installation & config
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   └── nginx.conf.j2
│   │   └── handlers/
│   │       └── main.yml
│   └── security/            # OS security hardening
│       ├── tasks/
│       │   └── main.yml
│       └── defaults/
│           └── main.yml
└── group_vars/
    └── webservers.yml       # Variables for webserver group
```

---

## Next Steps
- Read [04-Step-by-Step-Project-Guide.md](04-Step-by-Step-Project-Guide.md) for the complete build guide.

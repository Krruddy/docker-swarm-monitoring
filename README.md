# Getting started

Run the following commands:

```
set -a && source .env && set +a
```

# Docker Swarm

Installation of the Swarm.

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-doc podman-docker containerd runc | cut -f1)

# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt upgrade -y

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Check the Docker Daemon:

```bash
sudo systemctl status docker
sudo systemctl start docker
```

Add current user to `docker` group:

```bash
sudo usermod -aG $(whoami) docker
```

Enable Docker Swarm:

```bash
docker swarm init --advertise-addr <IP_ADDRESS>
```

Use the following command (on the same host) to get the join token for worker nodes:

```bash
docker swarm join-token manager
```

Setup the labels for the nodes:

```bash
docker node update --label-add hypervisor=hv-1 ${DOCKER_1_FQDN}
docker node update --label-add hypervisor=hv-2 ${DOCKER_2_FQDN}
docker node update --label-add hypervisor=hv-3 ${DOCKER_3_FQDN}
```

## Consul

Deploy the consul stack:

```bash
docker stack deploy --detach --compose-file ./stacks/consul/compose.consu.yml consul
```

Get the bootstrap token:

```
docker exec <container_id> consul acl bootstrap
```

### Configs

Create the config oject:

```bash
docker config create consul-server-config ./stacks/consul/consul-config.hcl
```

### Secrets

Create the secret objects:

```bash
echo "encrypt = \"`openssl rand -base64 32`\"" | docker secret create consul-gossip-key-v1 -
docker secret create consul-ca-v1 ./secrets/consul-agent-ca.pem
docker secret create consul-server1-cert-v1 ./secrets/dc1-server-consul-0.pem
docker secret create consul-server2-cert-v1 ./secrets/dc1-server-consul-1.pem
docker secret create consul-server3-cert-v1 ./secrets/dc1-server-consul-2.pem
docker secret create consul-server1-key-v1  ./secrets/dc1-server-consul-0-key.pem
docker secret create consul-server2-key-v1  ./secrets/dc1-server-consul-1-key.pem
docker secret create consul-server3-key-v1  ./secrets/dc1-server-consul-2-key.pem
```

# Consul

Setup Consul by using the following commands on each client node.

Install Consul:

```bash
sudo apt install gpg
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install consul
```

Get the encryption key on a Docker manager:

```bash
docker exec <container_id> cat /consul/config/zz-gossip.hcl
```

change rights:

```bash
sudo chmod 600 /etc/consul.d/zz-gossip.hcl
sudo chown consul:consul /etc/consul.d/zz-gossip.hcl
sudo chmod 600 dc1-client-consul-n-key.pem
sudo chmod 644 dc1-client-consul-n.pem
sudo chmod 644 consul-agent-ca.pem
sudo chown consul:consul /opt/consul/*.pem
```

```bash
sudo systemctl enable consul --now
```

configuration file:

```hcl
server = false
datacenter = "dc1"
data_dir = "/opt/consul"

retry_join = [
  "${DOCKER_1_FQDN}",
  "${DOCKER_2_FQDN}",
  "${DOCKER_3_FQDN}"
]

encrypt_verify_incoming = true
encrypt_verify_outgoing = true

acl {
  enabled = true
  default_policy = "deny"
  down_policy = "extend-cache"
  enable_token_persistence = true
}

tls {
  defaults {
    verify_incoming = true
    verify_outgoing = true
    ca_file = "/opt/consul/consul-agentca.pem"
    cert_file = "/opt/consul/dc1-client-consul-n.pem"
    key_file = "/opt/consul/dc1-client-consul-n-key.pem"
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

log_level = "INFO"
log_json = true
```


## Certificates

Generate certificates with the following commands in `./secrets/`:

```bash
cd ./secrets

# 1. Generate the CA
consul tls ca create

# 2. Generate server certs — one per Consul server node
# Run N times for N servers
consul tls cert create -server \
  -additional-dnsname=consul-1 \
  -additional-dnsname=${DOCKER_1_FQDN} \
  -additional-dnsname=${DOCKER_1_HOSTNAME} \
  -additional-ipaddress=${DOCKER_1_HOST_IP}

consul tls cert create -server \
  -additional-dnsname=consul-2 \
  -additional-dnsname=${DOCKER_2_FQDN} \
  -additional-dnsname=${DOCKER_2_HOSTNAME} \
  -additional-ipaddress=${DOCKER_2_HOST_IP}

consul tls cert create -server \
  -additional-dnsname=consul-3 \
  -additional-dnsname=${DOCKER_3_FQDN} \
  -additional-dnsname=${DOCKER_3_HOSTNAME} \
  -additional-ipaddress=${DOCKER_3_HOST_IP}

# 3. Generate client certs — one per Consul client
consul tls cert create -client \
  -additional-dnsname=${CONSUL_CLIENT_1_FQDN} \
  -additional-dnsname=${CONSUL_CLIENT_1_HOSTNAME} \
  -additional-ipaddress=${CONSUL_CLIENT_1_IP}

consul tls cert create -client \
  -additional-dnsname=${CONSUL_CLIENT_2_FQDN} \
  -additional-dnsname=${CONSUL_CLIENT_2_HOSTNAME} \
  -additional-ipaddress=${CONSUL_CLIENT_2_IP}

consul tls cert create -client \
  -additional-dnsname=${CONSUL_CLIENT_3_FQDN} \
  -additional-dnsname=${CONSUL_CLIENT_3_HOSTNAME} \
  -additional-ipaddress=${CONSUL_CLIENT_3_IP}
```

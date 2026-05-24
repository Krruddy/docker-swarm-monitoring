server = true
datacenter = "dc1"
bootstrap_expect = 3
ui_config {
  enabled = true
}
data_dir = "/consul/data"
retry_join = [
  "consul-1",
  "consul-2",
  "consul-3"
]

encrypt_verify_incoming = true
encrypt_verify_outgoing = true

acl {
  enabled = true
  default_policy = "deny"
  down_policy = "extend-cache"
}

tls {
  defaults {
    verify_incoming = true
    verify_outgoing = true
    ca_file = "/consul/tls/ca.pem"
    cert_file = "/consul/tls/server.pem"
    key_file = "/consul/tls/server-key.pem"
  }
  internal_rpc {
    verify_server_hostname = true
  }
}

log_level = "INFO"
log_json = true

path "secret/data/demo-app/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
path "secret/metadata/demo-app/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

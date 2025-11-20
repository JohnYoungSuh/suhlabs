kubectl run debug-coredns --rm -it --restart=Never \
  --image=nicolaka/netshoot \
  --overrides='
{
  "apiVersion": "v1",
  "spec": {
    "volumes": [{
      "name": "corp-zone",
      "configMap": { "name": "coredns" }
    }],
    "containers": [{
      "name": "debug",
      "image": "nicolaka/netshoot",
      "command": ["sleep", "3600"],
      "volumeMounts": [{
        "name": "corp-zone",
        "mountPath": "/etc/coredns/corp.local.db",
        "subPath": "corp.local.db"
      }]
    }]
  }
}' -- bash

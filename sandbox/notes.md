# WIP

### After bootstrap patch imageregistry
#### 4.3+
```
while [ $? != 0 ]; do sleep 10; ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'; done;
```
#### 4.2-
```
while [ $? != 0 ]; do sleep 10; ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'; done;
```

#### If you used the NFS yamls
4.3+
```
while [ $? != 0 ]; do sleep 10; ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"pvc":{"claim":""}}}}'; done;
```
4.2-
```
while [ $? != 0 ]; do sleep 10; ./oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'; done;
```

### Approve CSRs
```
oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

### Additional user accounts
```
sudo useradd -d /var/lib/coredns -m -r coredns
sudo useradd -d /var/lib/matchbox -m -r matchbox
```

### CoreDNS systemd unit /etc/systemd/system/coredns.service
```
[Unit]
Description=CoreDNS DNS server
Documentation=https://coredns.io
After=network.target

[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
LimitNPROC=512
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
User=coredns
WorkingDirectory=~
ExecStart=/usr/local/bin/coredns -conf=/etc/coredns/Corefile
ExecReload=/bin/kill -SIGUSR1 $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### Matchbox systemd unit /etc/systemd/system/matchbox.service
```
[Unit]
Description=CoreOS matchbox Server
Documentation=https://github.com/coreos/matchbox

[Service]
User=matchbox
Group=matchbox
ExecStart=/usr/local/bin/matchbox

# systemd.exec
ProtectHome=yes
ProtectSystem=full

[Install]
WantedBy=multi-user.target
```

### Matchbox systemd unit override /etc/systemd/system/matchbox.service.d/override.conf
```
[Service]
Environment="MATCHBOX_ADDRESS=0.0.0.0:8080"
Environment="MATCHBOX_RPC_ADDRESS=0.0.0.0:8081"
Environment="MATCHBOX_WEB_SSL=false"
Environment="MATCHBOX_WEB_CERT_FILE=/etc/matchbox/server.crt"
Environment="MATCHBOX_WEB_KEY_FILE=/etc/matchbox/server.key"
Environment="MATCHBOX_LOG_LEVEL=debug"
```

### CoreDNS Corefile /etc/coredns/Corefile (add 127.0.0.1 as a resolver)
```
. {
  bind 127.0.0.1 ::1
  forward . 128.104.222.8 128.104.222.9
  log
}

dev.lab {
  bind 127.0.0.1 ::1
  file /etc/coredns/db.dev.lab
  log
}

3scale.lab {
  bind 127.0.0.1 ::1
  file /etc/coredns/db.3scale.lab
  log
}
```

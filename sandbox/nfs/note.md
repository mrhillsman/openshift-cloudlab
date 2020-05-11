# Setting up NFS

```shell
oc apply -f sa.yaml
oc adm policy add-scc-to-user hostmount-anyuid system:serviceaccount:openshift-operators:nfs-client-provisioner
oc apply -f nfs.yaml
oc apply -f pvc.yaml
```

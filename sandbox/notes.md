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

#!/bin/bash

set -ex

# Export CLUSTER_DIR & KUBECONFIG
export CLUSTER_DIR="${HOME}/${CLUSTER_DOMAIN}/${CLUSTER_NAME}"

export KUBECONFIG="${CLUSTER_DIR}/auth/kubeconfig"
NAMESPACE=recycle-pvs
SERVICE_ACCOUNT=recycle-pvs-sa
RECYCLE_PV_POD=recycle-pvs

# create a namespace for recycle-pvs
cat << __EOF__ | oc create -f -
---
apiVersion: v1
kind: Namespace
metadata:
    name: ${NAMESPACE}
__EOF__

# create a service account
cat << __EOF__ | oc create -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
__EOF__

# create a cluster role binding
cat << __EOF__ | oc create -f -
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: recycle-pvs-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
__EOF__

# create the recycle pod
cat << __EOF__ | oc create -f -
---
kind: Pod
apiVersion: v1
metadata:
  name: ${RECYCLE_PV_POD}
  namespace: ${NAMESPACE}
  labels:
    name: ${RECYCLE_PV_POD}
spec:
  serviceAccountName: ${SERVICE_ACCOUNT}
  containers:
  - command:
    - /bin/bash
    - -c
    - /root/recycle-pvs.sh
    name: ${RECYCLE_PV_POD}
    image: quay.io/redhat/recycle-pvs
    resources: {}
    volumeMounts:
    imagePullPolicy: IfNotPresent
    securityContext:
      capabilities: {}
      privileged: true
  volumes:
  restartPolicy: Always
status: {}
__EOF__

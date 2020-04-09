#!/bin/bash -e

PROVISION_ON_NODE=$1
NAME_POSTFIX=$2 
TEST_NAMESPACE=test-migration-${NAME_POSTFIX}
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`


if [ -z "${PROVISION_ON_NODE}" ];
then
    echo "Missing provision on node. Please specify a worker node."
    echo "Usage: ./prepare-resources.sh <node_name> <0/1/2/3>"
    echo "oc get node"
    oc get node
    exit 1
fi

if [ -z "${NAME_POSTFIX}" ];
then
    echo "Missing postfix for resources name. You can specify 0, 1, 2, 3..."
    echo "Usage: ./prepare-resources.sh <node_name> <0/1/2/3>"
    exit 1
fi


oc new-project ${TEST_NAMESPACE}


cat > vm-cirros-dv.yaml << __EOF__
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: vm-cirros-dv-${NAME_POSTFIX}
  name: vm-cirros-dv-${NAME_POSTFIX}
spec:
  dataVolumeTemplates:
  - metadata:
      annotations:
        kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
      name: cirros-dv-${NAME_POSTFIX}
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100M
        storageClassName: kubevirt-hostpath-provisioner
      source:
        http:
          url: http://cnv-qe-server.rhevdev.lab.eng.rdu2.redhat.com/files/cdi-test-images/cirros_images/cirros-0.4.0-x86_64-disk.qcow2
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/vm: vm-datavolume
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: datavolumevolume
        machine:
          type: ""
        resources:
          requests:
            memory: 64M
      terminationGracePeriodSeconds: 0
      volumes:
      - dataVolume:
          name: cirros-dv-${NAME_POSTFIX}
        name: datavolumevolume
__EOF__

oc create -f vm-cirros-dv.yaml -n ${TEST_NAMESPACE}


cat > vm-fedora-dv.yaml << __EOF__
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: vm-fedora-dv-${NAME_POSTFIX}
  name: vm-fedora-dv-${NAME_POSTFIX}
spec:
  dataVolumeTemplates:
  - metadata:
      annotations:
        kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
      name: fedora-dv-${NAME_POSTFIX}
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 5Gi
        storageClassName: kubevirt-hostpath-provisioner
      source:
        http:
          url: http://cnv-qe-server.rhevdev.lab.eng.rdu2.redhat.com/files/fedora-images/Fedora-Cloud-Base-31-1.9.x86_64.qcow2
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/vm: vm-datavolume
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: datavolumevolume
        machine:
          type: ""
        resources:
          requests:
            memory: 512M
      terminationGracePeriodSeconds: 0
      volumes:
      - dataVolume:
          name: fedora-dv-${NAME_POSTFIX}
        name: datavolumevolume
__EOF__


oc create -f vm-fedora-dv.yaml -n ${TEST_NAMESPACE}


cat > vm-rhel-dv.yaml << __EOF__
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: vm-rhel-dv-${NAME_POSTFIX}
  name: vm-rhel-dv-${NAME_POSTFIX}
spec:
  dataVolumeTemplates:
  - metadata:
      annotations:
        kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
      name: rhel-dv-${NAME_POSTFIX}
    spec:
      pvc:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 12Gi
        storageClassName: kubevirt-hostpath-provisioner
      source:
        http:
          url: http://cnv-qe-server.rhevdev.lab.eng.rdu2.redhat.com/files/rhel-images/rhel-8/rhel-8.qcow2
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/vm: vm-datavolume
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: datavolumevolume
        machine:
          type: ""
        resources:
          requests:
            memory: 512M
      terminationGracePeriodSeconds: 0
      volumes:
      - dataVolume:
          name: rhel-dv-${NAME_POSTFIX}
        name: datavolumevolume
__EOF__


oc create -f vm-rhel-dv.yaml -n ${TEST_NAMESPACE}

sleep 10

echo "${yellow}oc get pvc ${reset}"
oc get pvc -n ${TEST_NAMESPACE}

echo "${yellow}oc get dv ${reset}"
oc get dv -n ${TEST_NAMESPACE}

echo "${yellow}oc get vm ${reset}"
oc get vm -n ${TEST_NAMESPACE}


virtctl start vm-cirros-dv-${NAME_POSTFIX}
virtctl start vm-rhel-dv-${NAME_POSTFIX}

sleep 10

echo "${yellow}oc get vmi ${reset}"
oc get vmi -n ${TEST_NAMESPACE}

echo "${yellow}oc get pod ${reset}"
oc get pod -o wide -n ${TEST_NAMESPACE} -w

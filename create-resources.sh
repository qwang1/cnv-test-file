#!/bin/bash -e

TEST_NAMESPACE=test-migration-1
PROVISION_ON_NODE=$1
NAME_POSTFIX=$2 

if [ -z "${PROVISION_ON_NODE}" ];
then
    echo "Missing provision on node. Please specify a worker node."
    echo "Usage: ./create-resources.sh <node_name> <0/1/2/3>"
    echo "oc get node"
    oc get node
    exit 1
fi

if [ -z "${NAME_POSTFIX}" ];
then
    echo "Missing postfix for resources name. You can specify 0, 1, 2, 3."
    echo "Usage: ./create-resources.sh <node_name> <0/1/2/3>"
    exit 1
fi


oc new-project ${TEST_NAMESPACE}


cat > hpp-pvc.yaml << __EOF__
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: hpp-pvc-${NAME_POSTFIX}
  annotations:
    kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
spec:
  storageClassName: kubevirt-hostpath-provisioner
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
__EOF__

oc create -f hpp-pvc.yaml -n ${TEST_NAMESPACE}


cat > hpp-pvc-import-cirros.yaml << __EOF__
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hpp-pvc-import-cirros-${NAME_POSTFIX}
  labels:
    app: containerized-data-importer
  annotations:
    kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
    cdi.kubevirt.io/storage.import.endpoint: "http://cnv-qe-server.rhevdev.lab.eng.rdu2.redhat.com/files/cdi-test-images/cirros_images/cirros-0.4.0-x86_64-disk.qcow2"
    cdi.kubevirt.io/storage.import.secretName: "" # Optional. The name of the secret containing credentials for the data source
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: kubevirt-hostpath-provisioner
__EOF__

oc create -f hpp-pvc-import-cirros.yaml -n ${TEST_NAMESPACE}


cat > hpp-dv-import-fedora.yaml << __EOF__
apiVersion: cdi.kubevirt.io/v1alpha1
kind: DataVolume
metadata:
  name: hpp-dv-import-fedora-${NAME_POSTFIX}
  annotations:
    kubevirt.io/provisionOnNode: ${PROVISION_ON_NODE}
spec:
  source:
      http:
         url: "http://cnv-qe-server.rhevdev.lab.eng.rdu2.redhat.com/files/fedora-images/Fedora-Cloud-Base-30-1.2.x86_64.qcow2"
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 5Gi
    storageClassName: kubevirt-hostpath-provisioner
__EOF__

oc create -f hpp-dv-import-fedora.yaml -n ${TEST_NAMESPACE}


oc get pvc -n ${TEST_NAMESPACE}


for pod in $(oc get pods -n ${TEST_NAMESPACE} -o go-template --template '{{range .items}}{{print .metadata.name " "}}{{end}}') ;
do
    oc wait pod $pod -n ${TEST_NAMESPACE} --for condition=Ready --timeout="300s"
done


oc get dv -n ${TEST_NAMESPACE}
oc get pv
oc get pod -o wide -n ${TEST_NAMESPACE}

sleep 10


cat > vm-pvc-hpp-pvc-import-pvc.yaml << __EOF__
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: vm-pvc
  name: vm-pvc-hpp-pvc-import-cirros-${NAME_POSTFIX}
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/vm: vm-pvc
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: mydisk
        machine:
          type: ""
        resources:
          requests:
            memory: 512M
      terminationGracePeriodSeconds: 0
      volumes:
      - name: mydisk
        persistentVolumeClaim:
          claimName: hpp-pvc-import-cirros-${NAME_POSTFIX}
__EOF__

oc create -f vm-pvc-hpp-pvc-import-pvc.yaml -n ${TEST_NAMESPACE}

sleep 5


cat > vm-pvc-hpp-dv-import-fedora.yaml << __EOF__
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: vm-pvc
  name: vm-pvc-hpp-dv-import-fedora-${NAME_POSTFIX}
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/vm: vm-pvc
    spec:
      domain:
        devices:
          disks:
          - disk:
              bus: virtio
            name: mydisk
        machine:
          type: ""
        resources:
          requests:
            memory: 512M
      terminationGracePeriodSeconds: 0
      volumes:
      - name: mydisk
        persistentVolumeClaim:
          claimName: hpp-dv-import-fedora-${NAME_POSTFIX}
__EOF__

oc create -f vm-pvc-hpp-dv-import-fedora.yaml -n ${TEST_NAMESPACE}

sleep 5

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


oc get vm -n ${TEST_NAMESPACE}

virtctl start vm-pvc-hpp-pvc-import-cirros-${NAME_POSTFIX}
virtctl start vm-pvc-hpp-dv-import-fedora-${NAME_POSTFIX}


sleep 10

oc get vmi -n ${TEST_NAMESPACE}
oc get pod -o wide -n ${TEST_NAMESPACE} -w


oc project ${TEST_NAMESPACE}

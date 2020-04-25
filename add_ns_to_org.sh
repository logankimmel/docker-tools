#!/bin/bash
# This script creates a new namespace and ties it to an organization
# * Requrires the environment variables: [NAMESPACE, PRODUCT, CPU_QUOTA, MEM_QUOTA, COST_CENTER]

echo "Adding NAMESPACE: $NAMESPACE to org: $PRODUCT with quotas CPU: $CPU_QUOTA, MEM: $MEM_QUOTA and Cost Center: $COST_CENTER"

if data=$(kubectl get cm/$PRODUCT-org -n kube-system -o json | jq -e -r .data) ; then
    echo "$data"
else
    exit 1
fi
org_id=$(echo $data | jq -r .org)
lead_id=$(echo $data | jq -r .lead)
dev_id=$(echo $data | jq -r .dev)
view_id=$(echo $data | jq -r .view)

echo "Creating namespace $NAMESPACE"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    cost-center: "${COST_CENTER}"
EOF

echo "Setting namespace resource quotas"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    limits.cpu: "${CPU_QUOTA}"
    limits.memory: "${MEM_QUOTA}"
EOF

echo "Creating K8s rolebinding for the view team"
kubectl create rolebinding $NAMESPACE:view --clusterrole=edit --group=team:$org_id:$view_id -n $NAMESPACE

echo "Creating K8s rolebindings for the dev team"
kubectl create rolebinding $NAMESPACE:edit --clusterrole=edit --group=team:$org_id:$dev_id -n $NAMESPACE

echo "Creating K8s rolebindings or the dev team"
kubectl create rolebinding $NAMESPACE:lead --clusterrole=edit --group=team:$org_id:$lead_id -n $NAMESPACE
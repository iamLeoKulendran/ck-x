#!/bin/bash
# Validate that the NetworkPolicy has correct selectors and egress rules

POLICY_NAME="api-server-policy"
NAMESPACE="api-restrict"

# Check if namespace exists
kubectl get namespace "$NAMESPACE" &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ Namespace '$NAMESPACE' not found"
  exit 1
fi

# Check if NetworkPolicy exists
kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" &> /dev/null
if [ $? -ne 0 ]; then
  echo "❌ NetworkPolicy '$POLICY_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Check if policy includes Egress in policyTypes
POLICY_TYPES=$(kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.policyTypes}')
if [[ "$POLICY_TYPES" != *"Egress"* ]]; then
  echo "❌ NetworkPolicy does not include Egress in policyTypes"
  exit 1
fi

# Check that podSelector is empty (applies to all pods in namespace)
POD_SELECTOR=$(kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.podSelector}')
if [[ "$POD_SELECTOR" != "{}" ]]; then
  echo "❌ NetworkPolicy podSelector must be empty ({}) to apply to all pods, got: $POD_SELECTOR"
  exit 1
fi

# Check that egress is defined (policy restricts egress, not just declares the type)
EGRESS_RULES=$(kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.egress}')
if [ -z "$EGRESS_RULES" ]; then
  echo "❌ NetworkPolicy has no egress rules defined"
  exit 1
fi

# Check that egress allows traffic to pods with role=admin label
if ! kubectl get networkpolicy "$POLICY_NAME" -n "$NAMESPACE" -o json | grep -q '"role"'; then
  echo "❌ NetworkPolicy egress does not reference role label selector for admin access"
  exit 1
fi

echo "✅ NetworkPolicy '$POLICY_NAME' is correctly configured"
exit 0

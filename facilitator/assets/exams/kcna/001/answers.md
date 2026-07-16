# KCNA Practice Exam 1 — Answers & Explanations

Original CK-X practice content. Not affiliated with CNCF or the Linux Foundation.

## Question 1 — Replica recovery
**Answer: B.** The ReplicaSet controller (owned by the Deployment) detects the missing replica and creates a replacement Pod; kube-scheduler places it on a healthy node. The kubelet cannot act for a dead node, and kube-proxy only programs Service networking.

## Question 2 — Scheduling
**Answer: C.** kube-scheduler watches unscheduled Pods and binds them to nodes. The API server stores state, the kubelet runs Pods it is told about, etcd is the datastore.

## Question 3 — Images vs containers
**Answer: B.** An image is an immutable layered filesystem plus metadata. A running container adds a writable layer and isolated namespaces, sharing the host kernel (no kernel inside the image).

## Question 4 — Namespaces
**Answers: A, C, D.** Namespaces scope quotas, RBAC, and names, and deleting one cascades to its contents. Nodes and PersistentVolumes are cluster-scoped. Namespaces do **not** isolate network traffic by default — NetworkPolicies do.

## Question 5 — Network model
**Answer: A.** Every Pod gets a unique IP and can reach every other Pod without NAT. CNI plugins (Flannel, Calico, Cilium, …) implement this contract.

## Question 6 — Durable storage
**Answer: C.** A PVC bound to a network-backed PV survives Pod restarts and rescheduling. emptyDir is deleted with the Pod; hostPath is pinned to one node.

## Question 7 — Workload identity
**Answer: B.** Pods run as a ServiceAccount whose projected token authenticates to the API server; RBAC then authorizes it.

## Question 8 — GitOps
**Answer: C.** Git holds the desired state; an in-cluster agent (Argo CD, Flux) continuously reconciles the cluster toward it.

## Question 9 — Observability pillars
**Answer: A.** Metrics, logs, and traces. OpenTelemetry is the CNCF standard for collecting and exporting them.

## Question 10 — Autoscaling
**Answer: B.** HPA changes replica counts from observed metrics. VPA adjusts Pod resources; Cluster Autoscaler adds/removes nodes.

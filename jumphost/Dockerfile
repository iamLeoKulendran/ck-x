# Base Image
FROM ubuntu:22.04

# Switch to root user for installations
USER 0

# Update and install required dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    openssh-server \
    vim \
    bash-completion\
    nano \
    docker.io\
    jq

# Accept build-time architecture argument
ARG TARGETARCH

#install kubectl for x86_64 and ARM64 architectures
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/kubectl; \
    fi

# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

# ─────────────────────────────────────────────────────
# CKS Security Tools — pinned static binaries
# ─────────────────────────────────────────────────────
ARG TRIVY_VERSION=0.71.0
ARG KUBE_BENCH_VERSION=0.15.6
ARG KUBESEC_VERSION=2.14.2
ARG COSIGN_VERSION=3.1.1
ARG SYFT_VERSION=1.45.1
ARG ETCDCTL_VERSION=3.6.12
ARG YQ_VERSION=4.53.3

# trivy
RUN ARCH="${TARGETARCH:-amd64}" && \
    TRIVY_ARCH=$([ "$ARCH" = "arm64" ] && echo "ARM64" || echo "64bit") && \
    curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin trivy && \
    chmod +x /usr/local/bin/trivy

# kube-bench
RUN ARCH="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}/kube-bench_${KUBE_BENCH_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin kube-bench && \
    chmod +x /usr/local/bin/kube-bench

# kubesec
RUN ARCH="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/kubesec_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin kubesec && \
    chmod +x /usr/local/bin/kubesec

# cosign (direct binary, no archive)
RUN ARCH="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}" \
    -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# syft
RUN ARCH="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /usr/local/bin syft && \
    chmod +x /usr/local/bin/syft

# etcdctl (extract only etcdctl from the etcd release bundle)
RUN ARCH="${TARGETARCH:-amd64}" && \
    mkdir -p /tmp/etcd-dl && \
    curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${ETCDCTL_VERSION}/etcd-v${ETCDCTL_VERSION}-linux-${ARCH}.tar.gz" \
    | tar -xz --strip-components=1 -C /tmp/etcd-dl && \
    mv /tmp/etcd-dl/etcdctl /usr/local/bin/etcdctl && \
    rm -rf /tmp/etcd-dl && \
    chmod +x /usr/local/bin/etcdctl

# yq (direct binary, no archive)
RUN ARCH="${TARGETARCH:-amd64}" && \
    curl -fsSL "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${ARCH}" \
    -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

#override docker daemon to use cfg2group
RUN echo '{ "exec-opts": ["native.cgroupdriver=cgroupfs"] }' > /etc/docker/daemon.json

# Set up SSH server
RUN mkdir -p /var/run/sshd

# Generate SSH host keys
RUN ssh-keygen -A

# Disable SSH authentication (VERY INSECURE: USE WITH CAUTION)
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
RUN sed -i 's/#UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
RUN echo "SetEnv KUBECONFIG=/home/candidate/.kube/config" >> /etc/ssh/sshd_config

# Completely remove password requirement
RUN echo "root::0:0:root:/root:/bin/bash" > /etc/passwd

# Create a new user 'candidate' with Docker permissions
RUN useradd -m candidate

#disable password login for candidate user
RUN echo "candidate::0:0:candidate:/home/candidate:/bin/bash" > /etc/passwd
RUN echo "candidate:x:1000:1000:candidate:/home/candidate:/bin/bash" >> /etc/passwd

# Set up Minikube cluster on startup
RUN mkdir -p /home/candidate/.kube /home/candidate/.minikube
RUN chown -R candidate: /home/candidate/.kube /home/candidate/.minikube

# CKA-style node helpers. These stay internal and do not expose new ports.
COPY ssh_config /tmp/ckx-ssh-config
RUN mkdir -p /home/candidate/.ssh && \
    cp /tmp/ckx-ssh-config /home/candidate/.ssh/config && \
    chown -R candidate: /home/candidate/.ssh && \
    chmod 700 /home/candidate/.ssh && \
    chmod 600 /home/candidate/.ssh/config

# Copy exam environment scripts
COPY scripts/prepare-exam-env.sh /usr/local/bin/prepare-exam-env
COPY scripts/cleanup-exam-env.sh /usr/local/bin/cleanup-exam-env

# Make scripts executable
RUN chmod +x /usr/local/bin/prepare-exam-env
RUN chmod +x /usr/local/bin/cleanup-exam-env

RUN mkdir -p /tmp/exam-env

# Expose SSH port
EXPOSE 22

RUN echo "export TERM=xterm" >> /home/candidate/.bashrc
RUN echo "export KUBECONFIG=/home/candidate/.kube/config" >> /home/candidate/.bashrc
RUN echo "PS1='\[\e[32m\]\u@\h:\w\$ \[\e[0m\]'" >> /home/candidate/.bashrc
RUN echo "alias controlplane='ssh controlplane'" >> /home/candidate/.bashrc
RUN echo "alias node01='ssh node01'" >> /home/candidate/.bashrc
RUN echo "alias node02='ssh node02'" >> /home/candidate/.bashrc

#set kubectl autocompletion
RUN echo "source /usr/share/bash-completion/bash_completion" >> /home/candidate/.bashrc && \
    echo "source <(kubectl completion bash)" >> /home/candidate/.bashrc && \
    echo "alias k=kubectl" >> /home/candidate/.bashrc && \
    echo "complete -F __start_kubectl k" >> /home/candidate/.bashrc && \
    echo "source <(helm completion bash)" >> /home/candidate/.bashrc

#start ssh service
RUN useradd -r -s /usr/sbin/nologin sshd
# RUN service ssh start

ENV CLUSTER_NAME=cluster

# Start SSH and Minikube on container start
CMD ["/bin/bash", "-c", "service ssh start && dockerd & tail -f /dev/null"]

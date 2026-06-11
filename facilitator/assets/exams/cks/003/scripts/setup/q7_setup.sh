#!/bin/bash
set -euo pipefail

kubectl create namespace host-audit --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q7
rm -f /tmp/exam/q7/disable-list.txt /tmp/exam/q7/insecure-api.txt

cat > /tmp/exam/q7/enabled-services.txt <<'SERVICES'
UNIT FILE                          STATE   PRESET
containerd.service                 enabled enabled
cron.service                       enabled enabled
dbus.service                       enabled enabled
docker.service                     enabled enabled
kubelet.service                    enabled enabled
rpcbind.service                    enabled enabled
sshd.service                       enabled enabled
systemd-networkd.service           enabled enabled
systemd-resolved.service           enabled enabled
telnet.socket                      enabled enabled
vsftpd.service                     enabled enabled

11 unit files listed.
SERVICES

cat > /tmp/exam/q7/listening-ports.txt <<'PORTS'
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=812,fd=3))
LISTEN  0       128     0.0.0.0:23          0.0.0.0:*          users:(("telnetd",pid=977,fd=4))
LISTEN  0       32      0.0.0.0:21          0.0.0.0:*          users:(("vsftpd",pid=985,fd=3))
LISTEN  0       4096    0.0.0.0:111         0.0.0.0:*          users:(("rpcbind",pid=655,fd=4))
LISTEN  0       4096    0.0.0.0:2375        0.0.0.0:*          users:(("dockerd",pid=1201,fd=8))
LISTEN  0       4096    127.0.0.1:10248     0.0.0.0:*          users:(("kubelet",pid=1090,fd=21))
LISTEN  0       4096    127.0.0.1:10249     0.0.0.0:*          users:(("kube-proxy",pid=1133,fd=12))
LISTEN  0       4096    127.0.0.53%lo:53    0.0.0.0:*          users:(("systemd-resolve",pid=601,fd=14))
PORTS

echo "Question 7 setup complete"

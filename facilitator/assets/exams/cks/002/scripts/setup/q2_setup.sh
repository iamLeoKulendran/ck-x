#!/bin/bash
set -euo pipefail

NS="tls-gateway"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q2

cat > /tmp/exam/q2/portal.crt <<'CRT'
-----BEGIN CERTIFICATE-----
MIIDPTCCAiWgAwIBAgIUSVNK5ursikMVeKr5iTy+/gCOEZEwDQYJKoZIhvcNAQEL
BQAwLjEZMBcGA1UEAwwQcG9ydGFsLmNreC5sb2NhbDERMA8GA1UECgwIY2t4LW1v
Y2swHhcNMjYwNjExMDAwODI0WhcNMzYwNjA4MDAwODI0WjAuMRkwFwYDVQQDDBBw
b3J0YWwuY2t4LmxvY2FsMREwDwYDVQQKDAhja3gtbW9jazCCASIwDQYJKoZIhvcN
AQEBBQADggEPADCCAQoCggEBAMlenVppjQmC0VCoInGjz9nU5IHah2qLl6YsQKfK
8Xgq/UnChzdEHY+foqcAnAXK+8cOMJBkcyA7n9551oljLxSpYxghh0G6SP9AI3/s
+AwYSFDR65+Tify2xTO16vc5OCrzw4PYyatAfXG+i2tKbNwpCavblpTE5sJpDWwD
J8b6/F27ubnvnwI9HNLOgqoLRxA/IyfF31NpmRsi4I1SGvt/kgHKH2fKreoMtGsf
cKLzIjvMPI8DMkE1cmotbh0S8eFlMQSbDqw1xwPxmfZB64fHmi8lWhNfb2pWBuDG
EN6hi+eZDy/eVG2U7qNx9v7N1V7cElYWGKmzqW0mVt1k/xkCAwEAAaNTMFEwHQYD
VR0OBBYEFMBOTtgNrH9lLQRaZ1CwP6iq9lFjMB8GA1UdIwQYMBaAFMBOTtgNrH9l
LQRaZ1CwP6iq9lFjMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEB
AJeOGSMZRZ+ILDzsdm5WQL1nHa++aco+8MZHpCoVuqht8x1ri6XeEBL6NaFBWY4j
UxUXeR3j3gFx3egv3kgWx2ismFEEqXwIGkexMpbr14tQbihAm2nS+Dx10KOAaByw
JZzGwJ4qa9Q2QUV8mXmrgV/bS3LB69hqAK2+MgkgvCxSx9GerGjF6fxVXe/io4ml
4XrSHINnGFa8kFbA54ynMHH0wCTw5C0D05oQGuSpQcyjNbt7gVchAy4VZN0uRyAU
npcpal3GjFRnxiR0LAlFOwBt/4ck3fNp+nj5r+3BuYgvlFbG7K/msRj0Et7KarPf
By1FeRRfmns8vHqByZSqJx4=
-----END CERTIFICATE-----
CRT

cat > /tmp/exam/q2/portal.key <<'KEY'
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDJXp1aaY0JgtFQ
qCJxo8/Z1OSB2odqi5emLECnyvF4Kv1Jwoc3RB2Pn6KnAJwFyvvHDjCQZHMgO5/e
edaJYy8UqWMYIYdBukj/QCN/7PgMGEhQ0eufk4n8tsUzter3OTgq88OD2MmrQH1x
votrSmzcKQmr25aUxObCaQ1sAyfG+vxdu7m5758CPRzSzoKqC0cQPyMnxd9TaZkb
IuCNUhr7f5IByh9nyq3qDLRrH3Ci8yI7zDyPAzJBNXJqLW4dEvHhZTEEmw6sNccD
8Zn2QeuHx5ovJVoTX29qVgbgxhDeoYvnmQ8v3lRtlO6jcfb+zdVe3BJWFhips6lt
JlbdZP8ZAgMBAAECggEABQsvIsgZBb92kbAcaL9DIgAglxYLpUII0tsx5WICaVGe
VX4fV+WHXgUQFGHCBq0eYE59LeiuL4T+zJo9ouROlhRmDIEue5l4YZhQK1Cap+bl
zMxtO+p8ns1PJCvuzjFrNDw1zfQcnQL5AWPV5yKOlncarGjMHT7PTthFw0pS8Ttl
vgN/Gg6UhSMjJJtU0x3rQE8GFbeOZONv22el1qPi/s5G6SXpnRrbRCqEu0tNvb+b
fHlfGLs7JB4gcxNu36esy91Zm8M7j0udGtnvS7GgZgyFnl6CNLmeILFW02D+UdY5
3v4YQPYcfHtljUQcvpFJ5XdQ6QNKvJd1xG6oS+iHwQKBgQDkvOj9zwudfhL6n0sR
Du3xqdu2XDcnr/EpI8IjQ5Lk3nkkLM4iBX6RVlRX3j6jNzsXZyj+MvYZK0Bd0+ma
wyVV+aUn9Jp4WJOHiXob0QBfd/rExGdrTHFCKEE2O7eLHwAwaG60oa9Gd4HuHeRR
NFS2K8Mm3eV9UNTEuN5RHahJyQKBgQDhXqk7ZwCclFv+1uFW3iMf3zXnGq6/rcoy
i3TR1Eca3oXPeK/D1XmDvNkMzv9dM/0X/wBqZprhgu2Vh7OTPXV0DXfpEv1+7did
IoCD5VOfm1Bu+LgSnDnqdgT7k4o94TtAo24n3H6FkGjtjDvY/nqb7H6fJ/9dN58h
O0Wlv5uy0QKBgQC6UywTu/mBNDavktyqK5gmGDBSjzGakZaH5Yn6AcyBxLu3fQv4
6LLeHw2bef1aJN5sxOq+jrKrc/D9vWZ4W+ho7W/caUL/L2AVsyYVzJ1aJzjN2hNI
cz97HaFpVSHBIOKdjCRJ3b8STr03Q4A9qbwrnOBeI7kR6Ks5CEKInvj8CQKBgF0l
sc6CeQc+bnN6vrIXp+7RY8b8CUPiAZM4fnUHRsg9NpMUr5jCT7H6SL95gqQ0C6Ry
WeqgM92HLslByB/QJA5uTqQ/nBRtG71+eB2LmC98kxb6p6HRfkKAuvh794Qx5jqG
Ec5Z3NU5ZZThBA9gxq5RZdhEQNB3X8btZ5DlC+YxAoGBAMU8W7xKDaYDWliVDx86
/epQkhLgh7/3knYT9w7K/942/BIiNPD9mSwaxtJp4g8dZqY/KBN+fOc7v7MtXrIE
7M5VahNOwJZFnKKrd0se3knvrL8cPLCT8Ma5J1bV3W5G0mzn2Onat1isDtWiOx51
9fFtvpswAq9LQoGBA/Yj2pKf
-----END PRIVATE KEY-----
KEY

chmod 644 /tmp/exam/q2/portal.crt
chmod 600 /tmp/exam/q2/portal.key

# Reset candidate-created objects so the question starts unsolved
kubectl -n "$NS" delete secret portal-tls --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete ingress portal-ingress --ignore-not-found=true >/dev/null 2>&1 || true

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: portal-web
  namespace: tls-gateway
  labels:
    app: portal-web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: portal-web
  template:
    metadata:
      labels:
        app: portal-web
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
YAML

cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Service
metadata:
  name: portal-svc
  namespace: tls-gateway
spec:
  selector:
    app: portal-web
  ports:
  - port: 80
    targetPort: 80
YAML

echo "Question 2 setup complete"

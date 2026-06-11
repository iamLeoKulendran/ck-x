#!/bin/bash
set -euo pipefail

NS="intra-tls"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

mkdir -p /tmp/exam/q9

# Reset: remove candidate-created secret and recreate workloads in plain-HTTP state
kubectl -n "$NS" delete secret orders-tls --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete deployment orders-app --ignore-not-found=true >/dev/null 2>&1 || true
kubectl -n "$NS" delete service orders-svc --ignore-not-found=true >/dev/null 2>&1 || true

# Issued certificate and key for orders-svc (pre-generated lab artifact)
cat > /tmp/exam/q9/orders.crt <<'CRT'
-----BEGIN CERTIFICATE-----
MIIDgjCCAmqgAwIBAgIUcmsF1JVO3JJA3UVijZYWcWH41JYwDQYJKoZIhvcNAQEL
BQAwIzEhMB8GA1UEAwwYb3JkZXJzLXN2Yy5pbnRyYS10bHMuc3ZjMB4XDTI2MDYx
MTA3MzU0NloXDTM2MDYwODA3MzU0NlowIzEhMB8GA1UEAwwYb3JkZXJzLXN2Yy5p
bnRyYS10bHMuc3ZjMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsfAp
yvM5PzHFY1pDqGHOIxrK49t6BU4Yb6apMdqSmaovNLmoxYkneNRDvEo8dAaJx0xi
s9U+uCdn0aec8YcJPBnhKSOy/sAoHu5Fk8SdruqxFxSWjyCxRRbxGE+lPVc5gIzX
ST9D6lsTg+FWkZ6cEZIhD4Jjzn2sE0k75557UXWqEeL6N7l0nrKToAJjnToSPXzv
ORlMmZMMYgdjZIwM0uKPyhmrC42hrqueD9QTYaVrz97DAcJE1zP0ooFEQ5EWeRPh
TBJRkhSST1ct2pf7hIpHvvIcA/WgyPXmhw26uTIJmg55CAaLSsMk+4CTSbZrNCkn
TJGGUsy8I8AH4O8+BQIDAQABo4GtMIGqMB0GA1UdDgQWBBRrJSQpuc37yy2kANxk
wcDjOLHNyzAfBgNVHSMEGDAWgBRrJSQpuc37yy2kANxkwcDjOLHNyzAPBgNVHRMB
Af8EBTADAQH/MFcGA1UdEQRQME6CCm9yZGVycy1zdmOCGG9yZGVycy1zdmMuaW50
cmEtdGxzLnN2Y4Imb3JkZXJzLXN2Yy5pbnRyYS10bHMuc3ZjLmNsdXN0ZXIubG9j
YWwwDQYJKoZIhvcNAQELBQADggEBAF9MEYqjSbj66DX1ooaBcnj0OJFbm7grb7Hx
skbaSses/RjiiUtUV5pHnDHN5rPJm0bK+/u5N8DB8TPOTgpnVjqSvAk30ihJBRag
HL5RZbdnAjwBbPg2aFascXDVxmTzrqccn9HMjkojpwR2RTZepooP76AA1x1s8ttR
1qkFl8AbyNzL2IqJgcR5BCRcNjyvPPSNaNwlCZQaVov6Gz9hdSPX1qIKu/Ke2l71
PmxnP6A0kf3MOmHRx9wZQpDFeZNsHi1bm7R4wN+Pe5XwjaFrszklLOiHl7in8Feo
KODSuvLYapH54Sflg8+jgK2lxIon7ydfBiA3eFpLuiXu17gMp0o=
-----END CERTIFICATE-----
CRT

cat > /tmp/exam/q9/orders.key <<'KEY'
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCx8CnK8zk/McVj
WkOoYc4jGsrj23oFThhvpqkx2pKZqi80uajFiSd41EO8Sjx0BonHTGKz1T64J2fR
p5zxhwk8GeEpI7L+wCge7kWTxJ2u6rEXFJaPILFFFvEYT6U9VzmAjNdJP0PqWxOD
4VaRnpwRkiEPgmPOfawTSTvnnntRdaoR4vo3uXSespOgAmOdOhI9fO85GUyZkwxi
B2NkjAzS4o/KGasLjaGuq54P1BNhpWvP3sMBwkTXM/SigURDkRZ5E+FMElGSFJJP
Vy3al/uEike+8hwD9aDI9eaHDbq5MgmaDnkIBotKwyT7gJNJtms0KSdMkYZSzLwj
wAfg7z4FAgMBAAECggEAB/Jw+2Z3hRIE/dX3NZsAqOK2cwzHW1tMjhgEcHyRlZlb
OGCeYAwrHiNkzxEFuCzelG8d7Wg1v+XKpjt1L/hW+j8xpjO499W/NPpxUxMx87D5
rc02mDfekvZeWDaea6nsoIgpyVSxBNOCgJ5czm4mDEbZgSbSrFNCjy3zJfoXCeFD
VZgIXLGcL23sXYyf2pio8J5s2P500cB5zKbWsjaMZThdOfhTRwVDDCYxjVlMrm70
neqWcFA5IfM7eYW5wV5UbUgpolKtYVqXlOudkpw5hzCIQ9pk1ZBgdpU4eh9M+r4p
6Jkdd/aczWcSwswCcIRVcCLUvaElx9aYwPuTy3wh4QKBgQDlApmd+I/VeG2W6ang
aPnq2ZyeQPAWxw3HSCLnbxd6boy/uDFPeVDairTi9XzSle0OVPBfp8PTm39CBGGw
PrfiB6CzttojmJsmQ0inDz/I9FJ9/FoVuBaWe4e/DzUyw8cwWMJEvAq7Qvt6oAE4
B3/u2w5h3H5aRexqZwMxtd1MjQKBgQDG6K8U/U50HW0mY97RdoBkJsvPOir5zjWL
UlY9xOSOkFlydPQOT/tZxw773U497tLy9pV+/4AyPuj2a/2IB0o5HNKxhRlrSEeT
GPvapnQV7Vv1G3wQchLQqzd8Rp/Y21dgDd5CXwsNKinIdJ543LCWBUr5LL0/uvqu
TvHFMfxlWQKBgQC0/ZgQ3Eg4ywO5mJQ0kmKp9DAudl4Jcmn2TJGhXRAuJ76/KsB1
8ggvoB4TnTZ4bBs9D24l+z3uOF+b+kCGfRrw3VxpjCLcrRg5ZkW+GnQrysSDY3SC
48meRqTjIA7IPyhmkk9+6SqGEwsTP++Wq361dJTqTMvjZo3RDfbdS8FJZQKBgQCz
nXJcldC+ccQaopyWsVeHGLF6U6BzK46WXKeb56wsQJVFEe9A7WCf1WzmaxU4P+0l
kR22LKpqtPxRaXrr1wljQW/Q9cvaYM6hOjJTY3P4SPp8/3CsuRXccIAOLQgzHv5r
spo9fO3R2X0ZkpV3tnGPRwBIuem7HvE3bfpMg7LTIQKBgG79kK5nPBTeMlGopCg5
JmHz8DCDoyA/5tZzLmUroiSixbtIBDn6vynwc3+KxcpLzN+SzsQDio/jbum5w2Qt
iKFDbEA6otiCvBsxwO3vuDoKrfus9TS5032gv+fSvsv9G/M7Ja+D4k71R1VEHf9l
weVZiLTsyp2PXT6BngdvZ8sN
-----END PRIVATE KEY-----
KEY

cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-tls-conf
  namespace: intra-tls
data:
  orders.conf: |
    server {
        listen 8443 ssl;
        ssl_certificate /etc/nginx/tls/tls.crt;
        ssl_certificate_key /etc/nginx/tls/tls.key;
        location / {
            return 200 "orders-api: secure\n";
        }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-app
  namespace: intra-tls
  labels:
    app: orders-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders-app
  template:
    metadata:
      labels:
        app: orders-app
    spec:
      containers:
      - name: orders
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: orders-svc
  namespace: intra-tls
spec:
  selector:
    app: orders-app
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments-client
  namespace: intra-tls
  labels:
    app: payments-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments-client
  template:
    metadata:
      labels:
        app: payments-client
    spec:
      containers:
      - name: client
        image: curlimages/curl:8.5.0
        command: ["sh", "-c", "sleep 2147483647"]
YAML

kubectl -n "$NS" rollout status deployment/orders-app --timeout=120s >/dev/null 2>&1 || true
kubectl -n "$NS" rollout status deployment/payments-client --timeout=120s >/dev/null 2>&1 || true

echo "Question 9 setup complete"

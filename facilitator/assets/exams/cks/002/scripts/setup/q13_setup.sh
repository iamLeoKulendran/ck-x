#!/bin/bash
set -euo pipefail

NS="sbom-lab"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

mkdir -p /tmp/exam/q13
rm -f /tmp/exam/q13/sbom.json /tmp/exam/q13/pkg-report.txt

# Plant the insecure Dockerfile (re-planting resets candidate fixes)
cat > /tmp/exam/q13/Dockerfile <<'DF'
FROM node:latest

ADD https://internal.example.com/tools/agent.sh /usr/local/bin/agent.sh

RUN curl -sf http://get.example.com/install.sh | sh

RUN chmod +x /usr/local/bin/agent.sh

ENV API_TOKEN=sk-live-9f8e7d6c5b4a

WORKDIR /app
COPY package.json .
RUN npm install
COPY . .

EXPOSE 3000
CMD ["node","server.js"]
DF

echo "Question 13 setup complete"

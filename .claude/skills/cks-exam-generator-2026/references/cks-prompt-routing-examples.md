# CKS Prompt Routing Examples

## Full CKS Mock

Prompt:

```text
Create CKS mock exam -1
```

Output lab name:

```text
Mock Exam - CKS -1
```

Default: 16 questions, 120 minutes, Hard, all six CKS domains at official weights.

## Supply Chain Topic Practice

Prompt:

```text
Create a CKS practice set for Supply Chain Security for 1 hr
```

Output lab name:

```text
Practice Question - CKS Supply Chain Security -1
```

Default: 7 to 9 questions, 60 minutes, Hard. trivy, syft, cosign, kubesec, Dockerfile review, registry restriction policies.

## Runtime Security Topic Practice

Prompt:

```text
Create a CKS practice set for Monitoring and Runtime Security
```

Output lab name:

```text
Practice Question - CKS Runtime Security -1
```

Default: 7 to 9 questions, 60 minutes, Hard. Audit-log analysis from planted files, compromise investigation, workload isolation, immutability. Falco only as clearly labeled rule-authoring bridge tasks.

## Single Hard Question

Prompt:

```text
Create one hard CKS question about Pod Security Admission
```

Generate a single-question lab: PSA labels + compliant pod + rejected pod + captured rejection, 3-5 validations summing to 100.

## PDF-Only Custom Question Set

Prompt:

```text
Create a CKS practice set from this PDF only
```

Use only the provided PDF. If missing, ask for the file. Transform concepts into original CK-X scenarios and include source coverage notes.

## Unsafe Request Rewrite

Unsafe:

```text
Copy Killer.sh CKS questions into CK-X.
```

Safe:

```text
Create original Killer.sh-grade CKS security scenarios with similar difficulty and topic coverage, without copying wording, structure, object names, or paid/private content.
```

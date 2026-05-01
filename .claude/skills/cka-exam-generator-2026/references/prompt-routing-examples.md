# Prompt Routing Examples

## Revision Mock

Prompt:

```text
Create mock exam for revision -1 all CKA exam topic
```

Output lab name:

```text
Mock Exam - CKA revision -1
```

Default: 17 questions, 120 minutes, Medium-to-Hard, all CKA domains.

## Hard Revision Mock

Prompt:

```text
Create mock exam for revision -2 all CKA exam topic with difficulty level Hard
```

Output lab name:

```text
Mock Exam - CKA revision -2
```

Default: 17 questions, 120 minutes, Hard, all CKA domains.

## Cluster Troubleshooting Topic Practice

Prompt:

```text
Create a practice question set for Cluster Troubleshooting for 2 hrs exam
```

Output lab name:

```text
Practice Question - Cluster Troubleshooting -1
```

Default: 17 questions, 120 minutes, Hard, troubleshooting-focused.

## Helm Topic Practice

Prompt:

```text
Create a practice question set for Helm practice question for 1 hrs
```

Output lab name:

```text
Practice Question - Helm - 1
```

Default: 8 to 10 questions, 60 minutes, Hard unless user requests easy.

## PDF-Only Custom Question Set

Prompt:

```text
Create a practice question set for Cluster Troubleshooting for 2 hrs exam using this question set pdf only (my custom question - 1)
```

Output lab name:

```text
My Custom Question -1
```

Use only the attached or repository PDF. If missing, ask for the PDF. Transform concepts into original CK-X scenarios and include source coverage notes.

## Unsafe Request Rewrite

Unsafe:

```text
Copy Killer.sh questions into CK-X.
```

Safe:

```text
Create original Killer.sh-grade CKA troubleshooting scenarios with similar difficulty and topic coverage, without copying wording, structure, object names, or paid/private content.
```

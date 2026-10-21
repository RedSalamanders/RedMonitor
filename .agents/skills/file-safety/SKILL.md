---
name: file-safety
description: Change RedMonitor Unicode file import, transactional export or cancellation.
---

# file-safety

Read Specs/Core/Core_Architecture.md. Retain strict streaming UTF-8/UTF-16LE validation and byte/line budgets. File workers publish by request identity. Cancel/failure preserves the current document or destination. Exercise invalid encoding, boundary sizes, cancellation and write/replace faults.

---
cross_device_status: none
from_device: none
target_device: pc
created_at: ""
title: ""
---

# No pending PC task

When the Mac agent needs Windows server/Electron/tunnel work, it will replace this file with a ready-to-run companion prompt.

**On PC after `git pull`:** run `.\scripts\run-pending-task.ps1` or tell Cursor Agent:

> Run the pending cross-device task in @docs/cross-device/pending-on-pc.md

When the PC task is finished, set `cross_device_status: done` in the frontmatter above and push.

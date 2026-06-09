---
cross_device_status: none
from_device: none
target_device: mac
created_at: ""
title: ""
---

# No pending Mac task

When the PC agent needs Mac/iOS/Xcode work, it will replace this file with a ready-to-run companion prompt.

**On Mac after `git pull`:** run `./scripts/run-pending-task.sh` or tell Cursor Agent:

> Run the pending cross-device task in @docs/cross-device/pending-on-mac.md

When the Mac task is finished, set `cross_device_status: done` in the frontmatter above and push.

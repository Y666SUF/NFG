#!/usr/bin/env node
/** After agent finishes: remind user to push and run pending task on other device. */
const {
  otherPendingPathForPlatform,
  readPendingMeta,
  isPending,
  deviceLabel,
  otherDeviceLabel,
} = require("./cross-device-lib");

async function main() {
  let input = "";
  for await (const chunk of process.stdin) input += chunk;

  const otherPath = otherPendingPathForPlatform();
  const meta = readPendingMeta(otherPath);
  if (!isPending(meta)) {
    process.stdout.write("{}");
    return;
  }

  const here = deviceLabel();
  const there = otherDeviceLabel();
  const pushCmd = here === "PC" ? ".\\scripts\\sync-push.ps1 \"...\"" : "./scripts/sync-push.sh \"...\"";
  const pullCmd = there === "PC" ? ".\\scripts\\sync-pull.ps1" : "./scripts/sync-pull.sh";
  const runCmd = there === "PC" ? ".\\scripts\\run-pending-task.ps1" : "./scripts/run-pending-task.sh";

  const title = meta.title ? `: ${meta.title}` : "";
  const followup = [
    `Cross-device task queued for ${there}${title}.`,
    `1) On ${here}: ${pushCmd}`,
    `2) On ${there}: ${pullCmd} then ${runCmd}`,
    `Or on ${there} Agent: @docs/cross-device/${there === "Mac" ? "pending-on-mac.md" : "pending-on-pc.md"}`,
  ].join(" ");

  process.stdout.write(JSON.stringify({ followup_message: followup }));
}

main().catch(() => process.stdout.write("{}"));

#!/usr/bin/env bash
# OPTIONAL backstop notifier. Hooks run shell commands and cannot call the Slack MCP,
# so this posts via a Slack incoming webhook (SLACK_WEBHOOK_URL). The slack-notifier
# agent (MCP) is the primary path; use this only if you want a ping even when the
# agent chain is interrupted. Safe to delete if you don't want it.
set -e
MSG="${1:-update}"
if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
  echo "SLACK_WEBHOOK_URL not set; skipping notification"; exit 0
fi
curl -fsS -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"${MSG}\"}" "$SLACK_WEBHOOK_URL" >/dev/null || true

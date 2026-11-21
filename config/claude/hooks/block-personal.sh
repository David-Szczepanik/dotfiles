#!/bin/sh
# PreToolUse hook: hard-block any tool call that touches the protected folder.
# Covers every tool (Read, Edit, Write, Grep, Glob, Bash, PowerShell, MCP, ...),
# because Read(...) deny rules alone do not cover shell commands.
#
# The folder name is assembled from two pieces so that editing this file does
# not trip the guard on its own source text.
#
# 1: a path descending into the folder   -> <seg>/ or <seg>\
# 2: a path ending at the folder itself  -> /<seg>" or \<seg>,
# A bare mention of the word in prose or in a grep pattern is NOT blocked.

if grep -qiE 'person'"al"'(/|\\)|(/|\\)person'"al"'("|,|[[:space:]]|$)'; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by the guard hook: that folder is off-limits to Claude. Ask the user to handle the file themselves."}}'
fi

exit 0

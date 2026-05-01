#!/usr/bin/env node
/**
 * HEDGE-REJECTOR — Stop hook
 *
 * Structural enforcement of HARD CONSTRAINT 1 (EVIDENCE BEFORE EXPLANATION).
 * Scans the assistant's last message for hedging language. If found, blocks
 * the turn with `decision: block` so the agent gets ONE retry to restate
 * without hedges. Universal — applies to every agent.
 *
 * Hook contract: receives JSON on stdin with shape:
 *   { hook_event_name, last_assistant_message, stop_hook_active, ... }
 * Outputs JSON on stdout when blocking; otherwise exits 0 silently.
 *
 * Failure mode: any internal error logs to stderr and exits 0 — a buggy hook
 * must never break a turn.
 */

import {
  detectHedges,
  stripFalsePositives,
  formatRejection,
} from "./lib/hedge-detection.mjs";

const EXIT_PASS = 0;

async function readStdin() {
  let raw = "";
  for await (const chunk of process.stdin) raw += chunk;
  return raw;
}

function block(message) {
  process.stdout.write(
    JSON.stringify({
      decision: "block",
      reason: message,
      stopReason: message,
      systemMessage: message,
    }),
  );
  process.exit(EXIT_PASS);
}

async function main() {
  const raw = await readStdin();
  if (!raw.trim()) process.exit(EXIT_PASS);

  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(EXIT_PASS);
  }

  if (input.hook_event_name !== "Stop") process.exit(EXIT_PASS);
  if (input.stop_hook_active) process.exit(EXIT_PASS); // already retried once

  const message = input.last_assistant_message;
  if (!message || !message.trim()) process.exit(EXIT_PASS);

  const cleaned = stripFalsePositives(message);
  const hits = detectHedges(cleaned);
  if (hits.length === 0) process.exit(EXIT_PASS);

  block(formatRejection(hits));
}

main().catch((err) => {
  console.error("[hedge-rejector]", err?.message ?? err);
  process.exit(EXIT_PASS);
});

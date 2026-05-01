/**
 * HEDGE DETECTION — Shared module
 *
 * Single-pass regex scan for hedge language in assistant output.
 * Backs the Stop hook (hedge-rejector.mjs) and any future PreToolUse hooks
 * that want to enforce HARD CONSTRAINT 1 (EVIDENCE BEFORE EXPLANATION).
 *
 * Design notes:
 *   - One combined alternation regex instead of N separate scans.
 *   - Phrases sorted longest-first so multi-word hedges win over substrings
 *     ("most likely" matches before "likely").
 *   - False-positive stripper removes code, quoted text, tool tags, URLs.
 *   - Detection result includes category, line, column, and a short snippet
 *     so the rejection message can point the agent at the offending phrase.
 */

// ============================================================================
// HEDGE PHRASES — grouped by category for telemetry/feedback
// ============================================================================

export const HEDGE_CATEGORIES = {
  // Agent claims uncertainty about its own knowledge
  epistemic: [
    "I think",
    "I believe",
    "I suspect",
    "I assume",
    "my guess is",
    "I would guess",
    "I'd guess",
    "I would say",
    "I'd say",
    "I'd imagine",
    "pretty sure",
    "fairly confident",
    "fairly certain",
    "I'm not sure",
    "not entirely sure",
    "to my knowledge",
    "as far as I can tell",
    "from what I can tell",
    "in my opinion",
    "if I recall",
    "if memory serves",
  ],

  // Probability / likelihood without evidence
  probability: [
    "probably",
    "likely",
    "most likely",
    "presumably",
    "apparently",
    "perhaps",
    "possibly",
    "potentially",
    "maybe",
    "in all likelihood",
    "chances are",
  ],

  // Claims something only "appears" true
  appearance: [
    "seems like",
    "seems to",
    "seems that",
    "appears to",
    "appears that",
    "looks like",
    "looks as if",
    "feels like",
  ],

  // Speculative modals
  modal: [
    "might be",
    "could be",
    "should be",
    "would be",
    "it's possible that",
    "it could be that",
  ],
};

// ============================================================================
// COMPILED ARTIFACTS (built once at module load)
// ============================================================================

const PHRASE_TO_CATEGORY = (() => {
  const map = new Map();
  for (const [category, phrases] of Object.entries(HEDGE_CATEGORIES)) {
    for (const phrase of phrases) map.set(phrase.toLowerCase(), category);
  }
  return map;
})();

const ALL_PHRASES = Object.values(HEDGE_CATEGORIES).flat();

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// One alternation regex, longest phrases first so "most likely" wins over "likely".
const HEDGE_REGEX = new RegExp(
  "\\b(?:" +
    [...ALL_PHRASES]
      .sort((a, b) => b.length - a.length)
      .map(escapeRegex)
      .join("|") +
    ")\\b",
  "gi",
);

// Patterns that surface false-positive content. Each is replaced with a single
// space so line numbers in the original text remain meaningful for column math
// only — line numbers are recomputed against the post-strip text.
const STRIP_PATTERNS = [
  /```[\s\S]*?```/g,                                          // fenced code
  /<teammate-message[\s\S]*?<\/teammate-message>/gi,          // teammate frames
  /<system-reminder>[\s\S]*?<\/system-reminder>/gi,           // system reminders
  /<[^>]+>[\s\S]*?<\/antml:[^>]+>/gi,                   // antml tags
  /<!--[\s\S]*?-->/g,                                          // HTML comments
  /`[^`\n]+`/g,                                                // inline code
  /\[([^\]]+)\]\(https?:[^)]+\)/g,                            // markdown links
  /https?:\/\/\S+/g,                                           // bare URLs
  /"[^"\n]{1,200}"/g,                                          // double-quoted spans
];

// ============================================================================
// FALSE-POSITIVE STRIPPING
// ============================================================================

/**
 * Remove content that should not be scanned:
 *   - Fenced code blocks
 *   - Inline code
 *   - HTML comments
 *   - Teammate-message / system-reminder / antml tag blocks
 *   - URLs (bare and inside markdown links)
 *   - Quoted text (likely citing the user)
 *   - Blockquote lines
 *   - 4-space-indented lines (markdown code)
 */
export function stripFalsePositives(text) {
  let cleaned = text;
  for (const re of STRIP_PATTERNS) cleaned = cleaned.replace(re, " ");

  cleaned = cleaned
    .split("\n")
    .filter((line) => {
      if (line.trimStart().startsWith(">")) return false;     // blockquote
      if (/^ {4}\S/.test(line)) return false;                  // indented code
      return true;
    })
    .join("\n");

  return cleaned;
}

// ============================================================================
// DETECTION
// ============================================================================

/**
 * @typedef {Object} HedgeHit
 * @property {string} phrase    Lower-cased matched phrase
 * @property {string} category  One of: epistemic | probability | appearance | modal
 * @property {number} line      1-indexed line number in the scanned text
 * @property {number} col       1-indexed column number
 * @property {string} snippet   ±30 char window around the match
 */

/**
 * Scan text for hedge phrases. Returns one hit per unique phrase
 * (first occurrence wins) sorted by source position.
 *
 * @param {string} text
 * @returns {HedgeHit[]}
 */
export function detectHedges(text) {
  if (!text || typeof text !== "string") return [];

  const hits = [];
  const seen = new Set();

  for (const match of text.matchAll(HEDGE_REGEX)) {
    const phrase = match[0].toLowerCase();
    if (seen.has(phrase)) continue;
    seen.add(phrase);

    const idx = match.index ?? 0;
    const before = text.slice(0, idx);
    const lastNl = before.lastIndexOf("\n");
    const line = (before.match(/\n/g)?.length ?? 0) + 1;
    const col = idx - lastNl;

    const start = Math.max(0, idx - 30);
    const end = Math.min(text.length, idx + match[0].length + 30);
    const snippet = text.slice(start, end).replace(/\s+/g, " ").trim();

    hits.push({
      phrase,
      category: PHRASE_TO_CATEGORY.get(phrase) ?? "unknown",
      line,
      col,
      snippet,
    });
  }

  return hits;
}

// ============================================================================
// REJECTION MESSAGE
// ============================================================================

/**
 * Build the human-readable rejection message shown to the agent on retry.
 * @param {HedgeHit[]} hits
 * @returns {string}
 */
export function formatRejection(hits) {
  const lines = [
    'Hedging detected. State as fact with cited evidence, or say "I don\'t know" explicitly.',
    "",
  ];
  for (const h of hits) {
    lines.push(
      `  • [${h.category}] "${h.phrase}" — line ${h.line}: …${h.snippet}…`,
    );
  }
  lines.push("");
  lines.push(
    'No "probably" / "I think" / "likely" — no soft middles. Retry without hedges.',
  );
  return lines.join("\n");
}

#!/usr/bin/env bash
# Cappy demo — pure stdout, no network, no side effects.
# Driven by .github/demo.tape via `bash assets/demo.sh`.

set -u

# Colors
RST=$'\e[0m'; B=$'\e[1m'; D=$'\e[2m'
R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'
BG=$'\e[92m'; BC=$'\e[96m'

pause() { sleep "${1:-1.5}"; }
hr()    { printf "${D}%s${RST}\n" "────────────────────────────────────────────────────────────────"; }

scene_banner() {
  clear
  cat <<EOF

   ${BC}${B}██████╗ █████╗ ██████╗ ██████╗ ██╗   ██╗${RST}
  ${BC}${B}██╔════╝██╔══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${RST}
  ${BC}${B}██║     ███████║██████╔╝██████╔╝ ╚████╔╝${RST}
  ${BC}${B}██║     ██╔══██║██╔═══╝ ██╔═══╝   ╚██╔╝${RST}
  ${BC}${B}╚██████╗██║  ██║██║     ██║        ██║${RST}
   ${BC}${B}╚═════╝╚═╝  ╚═╝╚═╝     ╚═╝        ╚═╝${RST}

       ${D}the Claude Code power-user toolkit${RST}

EOF
  pause 1.8
  printf "  ${G}\$${RST} curl -fsSL https://cappy.sh | bash\n\n"
  pause 0.8
  printf "  ${C}[info]${RST}  cloning cappy ${B}v3.2.0${RST}…\n";              pause 0.4
  printf "  ${G}[  ok]${RST}  17 modules installed\n";                          pause 0.25
  printf "  ${G}[  ok]${RST}  CLAUDE.md written to ~/Development\n";            pause 0.25
  printf "  ${G}[  ok]${RST}  hooks: post-edit-typecheck · file-guard · hedge-rejector\n"; pause 0.25
  printf "  ${G}[  ok]${RST}  statusline: enabled\n";                           pause 0.25
  printf "  ${G}[  ok]${RST}  MCP: github · linear · postgres · playwright\n"; pause 0.25
  printf "\n  ${B}${BG}done.${RST} ${D}cd into any project and run \`claude\`${RST}\n\n"
  pause 2.2
}

scene_pipeline() {
  clear
  printf "  ${G}\$${RST} cd ~/dev/my-app\n"
  pause 0.4
  printf "  ${G}\$${RST} claude ${Y}\"add a user dashboard with analytics\"${RST}\n\n"
  pause 0.9

  printf "  ${BC}${B}◇ Phase 1${RST} ${B}Discovery${RST}\n"
  pause 0.4
  printf "    ${D}↳${RST} scanning src/, reading routing patterns…\n"
  pause 0.5
  printf "    ${D}↳${RST} Research Brief written. ${B}3 open questions${RST}:\n"
  printf "       ${D}1.${RST} realtime updates or daily snapshot?\n"
  printf "       ${D}2.${RST} per-user or org-wide aggregates?\n"
  printf "       ${D}3.${RST} reuse recharts or new chart lib?\n\n"
  pause 1.3

  printf "  ${BC}${B}◇ Phase 2${RST} ${B}PRD${RST}                          ${Y}🔒 awaiting approval${RST}\n"
  pause 0.5
  printf "  ${BC}${B}◇ Phase 3${RST} ${B}Design${RST}                       ${D}gated on Phase 2${RST}\n"
  pause 0.4
  printf "  ${BC}${B}◇ Phase 4${RST} ${B}Build${RST}                        ${D}backend + frontend in parallel${RST}\n"
  pause 0.4
  printf "  ${BC}${B}◇ Phase 5${RST} ${B}Review${RST}                       ${D}OWASP + code quality${RST}\n"
  pause 0.4
  printf "  ${BC}${B}◇ Phase 6${RST} ${B}Validate${RST}                     ${D}type · lint · test · build · cov${RST}\n\n"
  pause 1.6
}

scene_diff() {
  clear
  printf "  ${B}what cappy stops claude from doing${RST}\n"
  hr
  printf "  ${R}✗${RST} ${D}\"This is probably caused by a stale cache…\"${RST}             ${R}→ rejected${RST}\n"
  pause 0.55
  printf "  ${R}✗${RST} ${D}\"All tests pass!\"  ${RST}${D}(actually never ran them)${RST}        ${R}→ blocked${RST}\n"
  pause 0.55
  printf "  ${R}✗${RST} ${D}50-file refactor in one sitting${RST}                          ${R}→ swarm split${RST}\n"
  pause 0.55
  printf "  ${R}✗${RST} ${D}\"I'll proceed with reasonable defaults\" ${RST}${D}(missing key)${RST}  ${R}→ BLOCKED${RST}\n"
  pause 0.55
  printf "  ${R}✗${RST} ${D}editing files from stale memory after compaction${RST}         ${R}→ re-reads first${RST}\n"
  pause 1.5
}

scene_statusline() {
  clear
  printf "\n  ${B}every claude session ends with this statusline:${RST}\n\n"
  pause 0.8
  printf "  ${BC}opus-4.7${RST}  ${G}▓▓▓▓▓▓▓░░░${RST} ${B}71%%${RST}   ${Y}main${RST} ${G}✓${RST}+3   ${B}tasks${RST} ${G}▓▓▓▓░░${RST} 4/6   ${G}\$0.42${RST}   ${D}12m${RST}   ${BG}↑ cappy v3.2.0${RST}\n\n"
  pause 2.5
}

scene_banner
scene_pipeline
scene_diff
scene_statusline

# Cappy demo tape — produces assets/demo.gif
#
# Prerequisites: brew install vhs
# Run:           vhs .github/demo.tape
# Output:        assets/demo.gif
#
# All visual content lives in assets/demo.sh — pure stdout, no network,
# no side effects. Edit that script to change what's recorded.

Output assets/demo.gif

Set Theme "Catppuccin Mocha"
Set FontSize 18
Set Width 1200
Set Height 720
Set Padding 28
Set TypingSpeed 0ms
Set PlaybackSpeed 1.0

Hide
Type "clear"
Enter
Sleep 200ms
Show

Type "bash assets/demo.sh"
Sleep 300ms
Enter

# demo.sh internal sleeps total ~21s — VHS only records during its own
# Sleep directives, so we hold here for the whole duration plus a tail.
Sleep 23s

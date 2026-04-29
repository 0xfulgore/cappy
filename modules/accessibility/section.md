<!-- cappy:section:accessibility -->
## Accessibility Standards

17. ACCESSIBLE BY DEFAULT: All UI code must meet WCAG 2.2 AA. This is not optional and not a follow-up task — it ships with the feature.

### Requirements
- **Keyboard navigation**: Every interactive element must be reachable and operable via keyboard. Tab order must be logical. Focus indicators must be visible.
- **Screen readers**: All images have alt text. All form inputs have labels. All buttons have accessible names. Use ARIA attributes when semantic HTML is insufficient — but prefer semantic HTML first.
- **Color contrast**: Text must meet 4.5:1 contrast ratio (3:1 for large text). Never convey information through color alone — use icons, patterns, or text alongside color.
- **Motion**: Respect `prefers-reduced-motion`. Animations must be subtle and non-essential. No auto-playing video or rapid flashing.
- **Touch targets**: Minimum 44x44px for all interactive elements on mobile.
- **Forms**: All errors must be announced. Required fields must be marked. Error messages must identify the field and describe the fix.

### Testing
- Run `axe-core` or equivalent accessibility scanner on new pages/components
- Test keyboard-only navigation for all new interactive flows
- If you add a modal, dropdown, or custom widget — verify it traps focus correctly and can be dismissed with Escape
<!-- cappy:end:accessibility -->

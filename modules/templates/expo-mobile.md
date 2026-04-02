# {{PROJECT_NAME}} — Development Guide

## Tech Stack
- **Framework**: Expo SDK {{EXPO_VERSION}} / React Native
- **Language**: TypeScript (strict)
- **Navigation**: {{NAVIGATION}}
- **State**: {{STATE_MANAGEMENT}}
- **Backend**: {{BACKEND}}

## Commands
```bash
npx expo start         # Start dev server
npx expo run:ios       # Run on iOS simulator
npx expo run:android   # Run on Android emulator
npm test               # Run tests
npx tsc --noEmit       # Type check
npx eslint .           # Lint
eas build              # Build for distribution
```

## Architecture
- `app/` — Expo Router file-based routes
- `components/` — Reusable UI components
- `hooks/` — Custom hooks
- `stores/` — State management
- `services/` — API clients, auth, storage
- `utils/` — Helpers and constants
- `assets/` — Images, fonts, static files

## Code Style
- TypeScript strict — no `any`
- Functional components with hooks only
- Use `StyleSheet.create()` — no inline styles
- Platform-specific code via `.ios.tsx` / `.android.tsx` suffixes
- Test with Jest + React Native Testing Library
- Accessibility: all touchable elements need accessibilityLabel

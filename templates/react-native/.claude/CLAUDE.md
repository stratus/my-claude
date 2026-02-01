# React Native/Expo Project Guidelines

Project-specific rules that extend global `~/.claude/CLAUDE.md`.

## Stack

- Expo SDK 53+, React Native 0.76+
- TypeScript strict mode
- expo-router for file-based navigation
- react-native-reanimated for animations

## Architecture

```
app/                  # expo-router screens
├── (tabs)/           # Tab navigator group
├── (auth)/           # Auth flow group
└── _layout.tsx       # Root layout
components/           # Reusable components
hooks/                # Custom hooks
lib/                  # Utilities
constants/            # Colors, sizes, config
```

## Rules

### Components
- Use `StyleSheet.create()` for styles, not inline objects
- Prefer `FlatList` over `ScrollView` + map for lists
- Use `FastImage` or `expo-image` with caching for images
- Implement skeleton loaders for async content

### Navigation
- Lazy load screens: `lazy: true` in navigator options
- Use typed navigation with expo-router
- Deep linking configuration in app.json

### Performance
- Use `react-native-reanimated` for 60fps animations
- Run animations on UI thread with `useAnimatedStyle`
- Avoid anonymous functions in render (use `useCallback`)
- Profile with Flipper or React DevTools

### Platform-Specific
- Use `Platform.select()` for platform differences
- Test on BOTH iOS and Android before PR
- Handle notch/safe areas with `SafeAreaView`

### Testing
- Jest + React Native Testing Library for unit tests
- Detox for E2E tests
- Test on physical devices, not just simulators

## Commands

```bash
npx expo start           # Development server
npx expo run:ios         # iOS build
npx expo run:android     # Android build
npm test                 # Run tests
npx expo-doctor          # Check for issues
```

## Build & Deploy

- EAS Build for cloud builds
- EAS Submit for store submissions
- OTA updates via EAS Update

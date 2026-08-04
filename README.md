# JataYuk

An AR educational app for kids built with SwiftUI + ARKit + RealityKit.

---

## Architecture: The Composable Architecture (TCA)

This project follows the **TCA (The Composable Architecture)** pattern with a feature-based folder structure.

### Folder Structure

```
JataYuk/
├── Core/
│   ├── MicroTCA/               # Gateway, routing, navigation
│   └── Environment/            # Shared dependencies & clients (network, AR, motion)
│
└── Features/
    ├── App/
    │   ├── RootReducer.swift   # Combines all feature reducers
    │   ├── RootView.swift      # Entry point view
    │   └── RootState.swift     # Global state shared across features
    │
    └── <FeatureName>/          # e.g. Experiment, Home, Onboarding
        ├── FeatureReducer.swift
        ├── FeatureView.swift
        └── FeatureState.swift
```

### TCA Data Flow

```
View → Action → Reducer ──→ update State → re-render View
                       └──→ Effects (async, AR, motion, API)
```

1. **View** dispatches an **Action** (e.g. button tap, tilt gesture)
2. **Reducer** receives `(state, action)` and returns a new state + optional `Effect`
3. **Effects** handle side effects (CoreMotion, ARKit, network) and feed new Actions back
4. **Store** holds the State and drives the View reactively

### Feature Example — Login

| Layer | Responsibility |
|---|---|
| `State` | `username`, `password`, `isLoading` |
| `Action` | `loginButtonTapped`, `usernameChanged`, `loginResponse` |
| `Reducer` | validates input, fires auth `Effect`, updates state |
| `Environment` | `authClient` injected as dependency |

### Why TCA

- Unidirectional data flow — easy to trace bugs
- Each feature is fully self-contained and testable in isolation
- Effects are explicit — no hidden side effects in views
- Scales cleanly as features are added

---

> PoC branch: see `PoC` for the working AR prototype (MVVM).
> This `main` branch is the clean slate for the TCA rewrite.

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

---

## GitHub Collaboration Rules

### Branch Protection — `main`

- **Never push directly to `main`** — all changes go through a Pull Request
- **Require at least 1 approval** before merging
- **Dismiss stale reviews** — new commits invalidate previous approvals
- **Branch must be up to date** with `main` before merging
- Only leads / admins can force-merge in an emergency

### Branch Naming

```
feature/<what-youre-building>      feature/experiment-ar-placement
fix/<what-youre-fixing>            fix/tilt-detection-threshold
chore/<maintenance-task>           chore/update-readme
refactor/<what-youre-changing>     refactor/tca-experiment-feature
```

### Commit Message Convention

```
feat: add yeast shake gesture
fix: tilt fires immediately on pickup
refactor: split coordinator into separate file
chore: update gitignore
style: clean up comments and headers
```

### Pull Request Rules

- PR title must follow the commit convention above
- Reference the related issue: `Closes #12`
- Keep PRs small and focused — one feature or fix per PR
- No self-merging — you cannot approve your own PR
- Must build without errors before requesting review

### Issues & Tasks

- Create a GitHub Issue before starting any work
- Assign every issue to a specific person — no orphan work
- Use labels: `feature` `bug` `chore` `refactor` `discussion`

### What NOT to Do

- Never commit directly to `main` or `PoC`
- Never commit API keys, secrets, or `.env` files
- Never commit `DerivedData/`, `.DS_Store`, or `xcuserdata/`
- Never merge your own PR without a review

### Recommended `.gitignore`

```
DerivedData/
*.xcuserstate
xcuserdata/
.DS_Store
*.moved-aside
```

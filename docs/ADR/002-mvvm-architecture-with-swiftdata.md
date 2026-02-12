# ADR-002: MVVM Architecture with SwiftData

## Decision

Use MVVM pattern with folder-based organization for scalability.

## Context

The project will grow to support multiple terminal sessions, custom themes, keybindings, and AI integration. Clear separation of concerns is essential for maintainability.

## Decision Rationale

- **Models/** — SwiftData entities, enums, and domain logic
- **ViewModels/** — View-specific state management and business logic coordination
- **Views/** — Pure SwiftUI views, organized by feature (`Terminal/`, `Settings/`, etc.)
- **Services/** — Reusable business logic (PTY management, shell execution, AI interactions)
- **Utilities/** — Helpers and extensions

## Consequences

- Clear boundaries between data, logic, and presentation
- Easier testing (mock services, isolated view models)
- Feature-based organization in Views/ for scalability
- SwiftData schema centralized in app entry point

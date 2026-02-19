# Phase 8: Split Panes

## Summary

Support horizontal and vertical terminal splits within a single tab. A terminal session can contain multiple split panes, each running an independent shell process. This enables side-by-side terminal workflows without switching tabs.

## Prerequisites

- Phase 1 complete (multi-session terminals with `TerminalManagerViewModel`, `TerminalViewWrapper`, cached views)
- Phase 2 recommended (profiles apply per-pane)

## Deliverables

### 1. `SplitConfiguration` Model

`Tenrec Terminal/Models/SplitConfiguration.swift`:
- Codable recursive tree structure:
  - `.single(paneId: UUID)` — leaf node, one terminal pane
  - `.horizontal(children: [SplitNode], proportions: [CGFloat])` — side-by-side
  - `.vertical(children: [SplitNode], proportions: [CGFloat])` — stacked
- `SplitNode`: enum wrapping `.single` or nested `.horizontal`/`.vertical`
- Proportions array sums to 1.0, defines relative sizing
- Utility methods: `addSplit(at paneId:, direction:)`, `removePane(paneId:)`, `updateProportion(at:, value:)`
- Minimum pane size constant: 120pt width, 80pt height

### 2. `TerminalSession` Extension

Modify `Tenrec Terminal/Models/TerminalSession.swift`:
- `splitConfig: SplitConfiguration?` — nil means single pane (default, backward compatible)
- `activePaneId: UUID?` — tracks focused pane within a split
- Split state persisted via SwiftData (Codable stored as JSON data)

### 3. `SplitPaneManager`

Part of `TerminalManagerViewModel` or standalone service:
- `splitHorizontally(sessionId:)` — splits the focused pane into two side-by-side panes
- `splitVertically(sessionId:)` — splits the focused pane into two stacked panes
- `closePane(sessionId:, paneId:)` — closes a pane and its PTY; if last split, collapses to single pane
- `focusPane(sessionId:, paneId:)` — updates `activePaneId`
- `navigateFocus(sessionId:, direction: FocusDirection)` — move focus left/right/up/down between panes
- Each new pane gets its own PTY process via `PTYService`
- `FocusDirection` enum: `.left`, `.right`, `.up`, `.down`

### 4. `TerminalContainerView`

`Tenrec Terminal/Views/Terminal/TerminalContainerView.swift`:
- Renders the split layout from `SplitConfiguration` tree
- Single pane: renders `TerminalViewWrapper` directly
- Split: recursive `HSplitView` (horizontal) / `VSplitView` (vertical) containing child views
- Each leaf node renders a `TerminalViewWrapper` with its own PTY

### 5. `SplitPaneView`

`Tenrec Terminal/Views/Terminal/SplitPaneView.swift`:
- Wraps a single `TerminalViewWrapper` within a split context
- Visual focus indicator: subtle border highlight (e.g., 1pt accent color border) on the active pane
- Minimum size constraints enforced

### 6. Split Divider Interaction

- Drag-to-resize split dividers updates proportions in `SplitConfiguration`
- Snap to equal sizing on double-click
- Minimum pane size constraints prevent collapsing a pane to zero

### 7. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+D | Split focused pane vertically |
| Cmd+Shift+D | Split focused pane horizontally |
| Cmd+Opt+Arrow | Navigate focus between panes |
| Cmd+Shift+W | Close focused pane |

### 8. Persistence

- `SplitConfiguration` persisted in `TerminalSession.splitConfig` via SwiftData
- On relaunch: layout restored, but PTY processes are not (new shells spawned per pane)
- Pane working directories preserved if stored

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Models/SplitConfiguration.swift` | Codable recursive tree, split/remove/resize operations |
| **Create** | `Tenrec Terminal/Views/Terminal/TerminalContainerView.swift` | Recursive split layout rendering |
| **Create** | `Tenrec Terminal/Views/Terminal/SplitPaneView.swift` | Single pane wrapper with focus indicator |
| **Modify** | `Tenrec Terminal/Models/TerminalSession.swift` | Add `splitConfig: SplitConfiguration?`, `activePaneId: UUID?` |
| **Modify** | `Tenrec Terminal/ViewModels/TerminalManagerViewModel.swift` | Split/close/focus operations, per-pane PTY management |
| **Modify** | `Tenrec Terminal/Views/ContentPaneView.swift` | Use `TerminalContainerView` instead of direct `TerminalViewWrapper` |
| **Create** | `Tenrec TerminalTests/SplitConfigurationTests.swift` | Tree operations, Codable round-trip, proportion math |
| **Create** | `Tenrec TerminalTests/SplitPaneManagerTests.swift` | Split/close/navigate operations, PTY lifecycle |

## Acceptance Criteria

- [ ] Cmd+D splits focused terminal vertically; Cmd+Shift+D splits horizontally
- [ ] Each pane runs an independent shell process with its own PTY
- [ ] Cmd+Opt+Arrow navigates focus between panes; focused pane has visible indicator
- [ ] Dragging divider resizes panes; minimum size enforced
- [ ] Cmd+Shift+W closes focused pane; closing last split returns to single-pane mode
- [ ] Nested splits work (splitting an already-split pane)
- [ ] Split configuration persists across relaunch (layout restored, new shells spawned)
- [ ] Sidebar still shows one entry per session (not per pane)
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`SplitConfigurationTests.swift`)
- Create single pane config, verify structure
- Split single into horizontal, verify two children with 50/50 proportions
- Split single into vertical, verify two children with 50/50 proportions
- Nested split: split one child of an existing split
- Remove pane from two-pane split: collapses to single
- Remove pane from three-pane split: remaining two maintain proportions
- Update proportion: verify values sum to 1.0
- Codable round-trip: encode and decode preserves full tree structure
- Deeply nested config (3+ levels) serializes correctly
- Minimum size constraints respected in proportion calculations

### Unit Tests (`SplitPaneManagerTests.swift`)
- Split creates new PTY process for new pane
- Close pane terminates its PTY process
- Focus navigation: left/right/up/down traverses panes correctly
- Focus wraps or stops at boundaries (define behavior)
- Closing focused pane moves focus to nearest sibling

### Integration Considerations
- Use in-memory SwiftData container for persistence tests
- Mock PTY service for pane lifecycle tests
- Test with `TerminalContainerView` in SwiftUI previews (in-memory data)

## Estimated Complexity

**High** — Recursive tree data structure with Codable serialization, recursive SwiftUI view rendering with `HSplitView`/`VSplitView`, per-pane PTY lifecycle management, focus traversal algorithm across a tree, and keyboard shortcut wiring. The main challenges are: (1) `SplitConfiguration` tree operations must maintain valid state (proportions sum to 1.0, no empty splits), (2) recursive SwiftUI view rendering with correct sizing, (3) focus navigation algorithm that maps arrow keys to tree traversal, and (4) managing multiple PTY processes per session.

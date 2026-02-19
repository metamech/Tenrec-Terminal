# Phase 4: Prompts & Templates (GitHub Issues #6, #7)

## Summary

Full data layer and UI for prompt snippets and parameterized templates. Prompts are markdown text snippets. Templates have `{{parameter}}` placeholders that generate prompts via a dynamic form. Both can be sent to an active terminal.

## Prerequisites

- Phase 1 complete (multi-session terminals with view caching and sidebar)
- SwiftData operational with `TerminalSession` model
- Sidebar supports dynamic sections

## Deliverables

### 1. `Prompt` SwiftData Model

`Tenrec Terminal/Models/Prompt.swift`:
- `id: UUID`
- `title: String`
- `content: String` (markdown)
- `category: String?`
- `isFavorite: Bool`
- `createdAt: Date`
- `updatedAt: Date`

### 2. `PromptTemplate` SwiftData Model

`Tenrec Terminal/Models/PromptTemplate.swift`:
- `id: UUID`
- `title: String`
- `templateBody: String` (contains `{{var}}` placeholders)
- `parameters: [TemplateParameter]` (stored as JSON)
- `category: String?`
- `createdAt: Date`
- `updatedAt: Date`

### 3. `TemplateParameter` Codable Struct

Embedded in `PromptTemplate.swift`:
- `name: String`
- `label: String`
- `defaultValue: String`
- `type: ParameterType` (enum: `.text`, `.multilineText`, `.choice`)
- `choices: [String]?`

### 4. `PromptViewModel` (@Observable)

- CRUD operations for prompts
- Search/filter by title and category
- Favorite toggle
- `sendToTerminal(sessionId:)` — writes prompt content to the selected terminal's PTY stdin

### 5. `TemplateViewModel` (@Observable)

- CRUD operations for templates
- Parameter value binding (dictionary of name -> current value)
- Template rendering: substitute `{{param}}` with bound values
- "Generate Prompt" action: creates a new `Prompt` from rendered template output

### 6. Sidebar Sections

- **Prompts** section: populated from `@Query`, search/filter bar
- **Templates** section: populated from `@Query`, search/filter bar

### 7. Content Pane Views

- **PromptEditorView**: `TextEditor` for markdown content with rendered preview toggle (using `AttributedString`)
- **TemplateEditorView**: `TextEditor` with `{{param}}` syntax awareness, parameter definition form below

### 8. Detail/Inspector Pane Views

- **PromptDetailView**: title, category, dates, favorite toggle, "Send to Terminal" dropdown (lists active sessions)
- **TemplateParameterFormView**: dynamic form generated from template parameters, live preview of rendered output, "Generate Prompt" button

### 9. "Send to Terminal" Action

Writes the prompt text to the selected terminal's PTY stdin. Dropdown lists all sessions with `.active` status.

### 10. Toolbar Actions

- New Prompt button
- New Template button
- Delete button (with confirmation alert)

## Files to Create/Modify

| Action | File | Changes |
|--------|------|---------|
| **Create** | `Tenrec Terminal/Models/Prompt.swift` | SwiftData @Model with fields above |
| **Create** | `Tenrec Terminal/Models/PromptTemplate.swift` | SwiftData @Model + `TemplateParameter` Codable struct |
| **Create** | `Tenrec Terminal/ViewModels/PromptViewModel.swift` | CRUD, search, favorite, sendToTerminal |
| **Create** | `Tenrec Terminal/ViewModels/TemplateViewModel.swift` | CRUD, parameter binding, rendering, generate prompt |
| **Create** | `Tenrec Terminal/Views/Prompts/PromptEditorView.swift` | Markdown editor with preview toggle |
| **Create** | `Tenrec Terminal/Views/Prompts/PromptDetailView.swift` | Inspector view with send-to-terminal |
| **Create** | `Tenrec Terminal/Views/Prompts/TemplateEditorView.swift` | Template body editor + parameter definition form |
| **Create** | `Tenrec Terminal/Views/Prompts/TemplateParameterFormView.swift` | Dynamic form, live preview, generate button |
| **Modify** | `Tenrec Terminal/Views/SidebarView.swift` | Add Prompts and Templates sections with search/filter |
| **Modify** | `Tenrec Terminal/Views/ContentPaneView.swift` | Route to PromptEditorView / TemplateEditorView |
| **Modify** | `Tenrec Terminal/Views/DetailPaneView.swift` | Route to PromptDetailView / TemplateParameterFormView |
| **Modify** | `Tenrec Terminal/Tenrec_TerminalApp.swift` | Add `Prompt` and `PromptTemplate` to SwiftData schema |
| **Create** | `Tenrec TerminalTests/PromptViewModelTests.swift` | CRUD, search, favorite toggle tests |
| **Create** | `Tenrec TerminalTests/TemplateViewModelTests.swift` | CRUD, parameter binding tests |
| **Create** | `Tenrec TerminalTests/TemplateRenderingTests.swift` | Substitution logic, edge cases |

## Acceptance Criteria

- [ ] Create, edit, and delete prompts and templates; data persists across relaunch
- [ ] Template rendering substitutes all `{{parameter}}` placeholders correctly
- [ ] Dynamic parameter form generates correct input fields per parameter type (text field, multiline text area, picker for choices)
- [ ] "Send to Terminal" writes text to selected terminal's PTY stdin
- [ ] "Generate Prompt" creates a new `Prompt` from rendered template and navigates to it
- [ ] Search/filter works in sidebar for both prompts and templates
- [ ] Markdown preview renders headings, bold, italic, code blocks via `AttributedString`
- [ ] `make test` passes
- [ ] `make build` succeeds
- [ ] App Sandbox entitlement unchanged

## Testing Requirements

### Unit Tests (`PromptViewModelTests.swift`)
- Create prompt, verify fields persisted
- Update prompt title/content, verify changes
- Delete prompt, verify removal
- Favorite toggle updates `isFavorite`
- Search by title returns correct results
- Filter by category returns correct results

### Unit Tests (`TemplateViewModelTests.swift`)
- Create template with parameters
- Update template body and parameters
- Delete template

### Unit Tests (`TemplateRenderingTests.swift`)
- Single parameter substitution
- Multiple parameter substitution
- Parameter with default value used when no input provided
- Missing parameter leaves placeholder or uses empty string (define behavior)
- Nested/escaped braces `{{{param}}}` handled gracefully
- Empty parameter values
- Template with no parameters renders as-is
- Choice parameter type validates against allowed choices

### Integration Considerations
- Use in-memory SwiftData container for all tests
- Send-to-terminal: mock PTY service to verify correct data written to stdin
- Search/filter accuracy with mixed content

## Estimated Complexity

**Medium-High** — The data models and CRUD are straightforward. The main challenges are: (1) template rendering with edge cases around brace parsing, (2) dynamic form generation from parameter definitions, (3) markdown preview with `AttributedString`, and (4) wiring "Send to Terminal" through to the PTY layer.

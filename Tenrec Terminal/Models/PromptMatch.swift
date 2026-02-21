import Foundation

/// Categories of detected prompts in terminal output.
enum PromptCategory: String, Sendable, CaseIterable {
    case confirmation    // Y/N, yes/no, proceed/continue
    case authorization   // allow/deny/permit/reject
    case continuation    // press enter to continue
    case claudeCode      // Claude Code tool approval
    case credential      // password/passphrase prompts
    case unknown
}

/// Result of matching a terminal line against prompt patterns.
struct PromptMatch: Sendable {
    let line: Int               // Line number in the scanned range
    let matchedText: String     // The text that was matched
    let category: PromptCategory
    let patternLabel: String    // Human-readable pattern name
}

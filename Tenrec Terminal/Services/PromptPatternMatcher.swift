import Foundation
import os.log

/// Regex-based engine that detects interactive prompts in terminal output lines.
///
/// All ANSI escape sequences are stripped from input before matching.
/// Built-in patterns are ordered by specificity (most specific first).
/// User-defined patterns are loaded from UserDefaults and appended after built-in patterns.
struct PromptPatternMatcher: Sendable {

    // MARK: - Types

    private struct CompiledPattern: Sendable {
        let regex: NSRegularExpression
        let category: PromptCategory
        let label: String
    }

    // MARK: - Properties

    private let patterns: [CompiledPattern]

    private static let logger = Logger(subsystem: "com.metamech.TenrecTerminal", category: "PromptPatternMatcher")

    // MARK: - ANSI Stripping

    /// Strip all ANSI escape sequences from a string before pattern matching.
    ///
    /// Handles:
    /// - CSI sequences: `ESC [ <params> <letter>`  (SGR, cursor movement, etc.)
    /// - OSC sequences: `ESC ] <text> BEL|ST`      (window title, hyperlinks, etc.)
    /// - Designate Character Set: `ESC ( <A|B|0|1|2>`
    static func stripANSI(_ input: String) -> String {
        // Single regex covering the three common ANSI sequence families.
        // Compiled once as a static constant; NSRegularExpression is thread-safe for matching.
        let stripped = ansiRegex.stringByReplacingMatches(
            in: input,
            range: NSRange(input.startIndex..., in: input),
            withTemplate: ""
        )
        return stripped
    }

    // Static storage so the regex is compiled exactly once across all matcher instances.
    private static let ansiRegex: NSRegularExpression = {
        // Pattern breakdown:
        //   \x1B\[[0-9;]*[A-Za-z]          — CSI sequences (ESC [ params letter)
        //   \x1B\][^\x07\x1B]*(?:\x07|\x1B\\) — OSC sequences (ESC ] text BEL|ST)
        //   \x1B\([A-B0-2]                 — Designate Character Set sequences
        let pattern = "\u{1B}(?:\\[[0-9;]*[A-Za-z]|\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)|\\([A-B0-2])"
        // Force-try is safe: the pattern is a compile-time constant and has been validated.
        // swiftlint:disable:next force_try
        return try! NSRegularExpression(pattern: pattern)
    }()

    // MARK: - Matching

    /// Match a single line against all compiled patterns. Returns the first match found, or nil.
    ///
    /// The line is ANSI-stripped before matching. Built-in patterns take precedence over
    /// user-defined patterns because they are prepended during initialisation.
    func match(line: String, lineNumber: Int) -> PromptMatch? {
        let clean = Self.stripANSI(line)
        let range = NSRange(clean.startIndex..., in: clean)

        for compiled in patterns {
            guard compiled.regex.firstMatch(in: clean, range: range) != nil else {
                continue
            }
            return PromptMatch(
                line: lineNumber,
                matchedText: clean,
                category: compiled.category,
                patternLabel: compiled.label
            )
        }
        return nil
    }

    /// Match multiple lines and return every match found (one per line, first pattern wins).
    func matchAll(lines: [String]) -> [PromptMatch] {
        lines.enumerated().compactMap { index, line in
            match(line: line, lineNumber: index)
        }
    }

    // MARK: - Initialisation

    /// Creates a matcher with all built-in patterns plus any valid user-defined patterns
    /// loaded from `UserDefaults.standard` under the key `"customPromptPatterns"`.
    init() {
        var compiled: [CompiledPattern] = []

        // Built-in patterns — ordered from most specific to least specific so the first
        // match returned by `match(line:lineNumber:)` is always the most meaningful one.
        let builtIn: [(label: String, pattern: String, category: PromptCategory)] = [
            (
                label: "Claude Code tool",
                pattern: "Do you want to run",
                category: .claudeCode
            ),
            (
                label: "Allow/Deny",
                pattern: "(?i)(allow|deny|permit|reject)",
                category: .authorization
            ),
            (
                label: "Overwrite",
                pattern: "(?i)overwrite.*\\?",
                category: .confirmation
            ),
            (
                label: "Proceed/Continue",
                pattern: "(?i)do you want to (proceed|continue)",
                category: .confirmation
            ),
            (
                label: "Yes/No prompt",
                pattern: "(?i)\\(y(?:es)?/n(?:o)?\\)",
                category: .confirmation
            ),
            (
                label: "Y/N bracket",
                pattern: "\\[Y/n\\]|\\[y/N\\]",
                category: .confirmation
            ),
            (
                label: "Press Enter",
                pattern: "(?i)press (enter|return) to continue",
                category: .continuation
            ),
            (
                label: "Password prompt",
                pattern: "(?i)(password|passphrase):?\\s*$",
                category: .credential
            ),
        ]

        for entry in builtIn {
            do {
                let regex = try NSRegularExpression(pattern: entry.pattern)
                compiled.append(CompiledPattern(regex: regex, category: entry.category, label: entry.label))
            } catch {
                // Built-in patterns should never fail; log and continue rather than crashing.
                Self.logger.error("Failed to compile built-in pattern '\(entry.label)': \(error.localizedDescription)")
            }
        }

        // User-defined patterns — loaded from UserDefaults, invalid regex skipped (not fatal).
        let userPatterns = Self.loadUserPatterns()
        for entry in userPatterns {
            do {
                let regex = try NSRegularExpression(pattern: entry.pattern)
                let category = PromptCategory(rawValue: entry.category) ?? .unknown
                compiled.append(CompiledPattern(regex: regex, category: category, label: entry.label))
            } catch {
                Self.logger.warning(
                    "Skipping invalid custom prompt pattern '\(entry.label)' ('\(entry.pattern)'): \(error.localizedDescription)"
                )
            }
        }

        self.patterns = compiled
    }

    // MARK: - Private Helpers

    private struct UserPatternEntry {
        let pattern: String
        let category: String
        let label: String
    }

    /// Load user-defined pattern dictionaries from UserDefaults.
    /// Entries that are missing required keys are silently skipped.
    private static func loadUserPatterns() -> [UserPatternEntry] {
        guard
            let raw = UserDefaults.standard.array(forKey: "customPromptPatterns"),
            !raw.isEmpty
        else {
            return []
        }

        var result: [UserPatternEntry] = []
        for item in raw {
            guard
                let dict = item as? [String: String],
                let pattern = dict["pattern"], !pattern.isEmpty,
                let label = dict["label"], !label.isEmpty
            else {
                logger.warning("Skipping malformed custom prompt pattern entry (missing 'pattern' or 'label' key)")
                continue
            }
            let category = dict["category"] ?? PromptCategory.unknown.rawValue
            result.append(UserPatternEntry(pattern: pattern, category: category, label: label))
        }
        return result
    }
}

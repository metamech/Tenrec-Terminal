import Foundation
import Testing
@testable import Tenrec_Terminal

// MARK: - ANSI Stripping Tests

@Suite("PromptPatternMatcher.stripANSI")
struct PromptPatternMatcherANSITests {

    @Test("stripANSI removes CSI SGR color codes")
    func stripCSISGRCodes() {
        let input = "Hello \u{1B}[31mRed\u{1B}[0m World"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "Hello Red World")
    }

    @Test("stripANSI removes CSI cursor movement sequences")
    func stripCSICursorMovement() {
        let input = "Line\u{1B}[2A\u{1B}[5GText"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "LineText")
    }

    @Test("stripANSI removes multiple SGR codes in sequence")
    func stripMultipleSGRCodes() {
        let input = "\u{1B}[1m\u{1B}[32mBold Green\u{1B}[0m"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "Bold Green")
    }

    @Test("stripANSI removes OSC sequences with BEL terminator")
    func stripOSCSequencesBEL() {
        let input = "Title\u{1B}]\u{07}Normal"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "TitleNormal")
    }

    @Test("stripANSI removes OSC sequences with ST terminator")
    func stripOSCSequencesST() {
        let input = "Title\u{1B}]0;MyTitle\u{1B}\\Normal"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "TitleNormal")
    }

    @Test("stripANSI removes Designate Character Set sequences")
    func stripDesignateCharacterSet() {
        let input = "Text\u{1B}(BMore"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "TextMore")
    }

    @Test("stripANSI handles text with no ANSI sequences")
    func stripANSINoSequences() {
        let input = "Plain text with no codes"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "Plain text with no codes")
    }

    @Test("stripANSI handles empty string")
    func stripANSIEmpty() {
        let result = PromptPatternMatcher.stripANSI("")
        #expect(result == "")
    }

    @Test("stripANSI removes complex nested ANSI codes")
    func stripComplexNestedCodes() {
        let input = "\u{1B}[1m\u{1B}[32mStatus: \u{1B}[0m\u{1B}[1m\u{1B}[31mRunning\u{1B}[0m"
        let result = PromptPatternMatcher.stripANSI(input)
        #expect(result == "Status: Running")
    }
}

// MARK: - Pattern Matching Tests

@Suite("PromptPatternMatcher.match")
struct PromptPatternMatcherPatternTests {

    let matcher = PromptPatternMatcher()

    // MARK: Claude Code Pattern

    @Test("matches Claude Code tool prompt")
    func matchClaudeCodePrompt() {
        let match = matcher.match(line: "Do you want to run this tool?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .claudeCode)
        #expect(match?.patternLabel == "Claude Code tool")
        #expect(match?.line == 0)
    }

    @Test("matches Claude Code with ANSI codes present")
    func matchClaudeCodeWithANSI() {
        let line = "\u{1B}[1mDo you want to run\u{1B}[0m this tool?"
        let match = matcher.match(line: line, lineNumber: 5)
        #expect(match != nil)
        #expect(match?.category == .claudeCode)
    }

    // MARK: Authorization Pattern

    @Test("matches Allow/Deny authorization prompt")
    func matchAllowDeny() {
        let match = matcher.match(line: "Allow or Deny?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .authorization)
    }

    @Test("matches Allow/Deny case insensitive")
    func matchAllowDenyCaseInsensitive() {
        let match = matcher.match(line: "ALLOW or DENY?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .authorization)
    }

    @Test("matches Permit/Reject authorization prompt")
    func matchPermitReject() {
        let match = matcher.match(line: "Permit or Reject?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .authorization)
    }

    // MARK: Confirmation Pattern - Overwrite

    @Test("matches Overwrite existing file prompt")
    func matchOverwrite() {
        let match = matcher.match(line: "Overwrite existing file?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
        #expect(match?.patternLabel == "Overwrite")
    }

    @Test("matches overwrite case insensitive")
    func matchOverwriteCaseInsensitive() {
        let match = matcher.match(line: "OVERWRITE EXISTING FILE?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    // MARK: Confirmation Pattern - Proceed/Continue

    @Test("matches Do you want to proceed prompt")
    func matchProceed() {
        let match = matcher.match(line: "Do you want to proceed?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches Do you want to continue prompt")
    func matchContinue() {
        let match = matcher.match(line: "Do you want to continue?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches proceed case insensitive")
    func matchProceedCaseInsensitive() {
        let match = matcher.match(line: "DO YOU WANT TO PROCEED?", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    // MARK: Confirmation Pattern - Yes/No Parentheses

    @Test("matches (y/n) prompt")
    func matchYN() {
        let match = matcher.match(line: "Continue? (y/n)", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches (yes/no) prompt")
    func matchYesNo() {
        let match = matcher.match(line: "Continue? (yes/no)", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches (y/n) case insensitive")
    func matchYNCaseInsensitive() {
        let match = matcher.match(line: "Continue? (Y/N)", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    // MARK: Confirmation Pattern - Bracket Format

    @Test("matches [Y/n] bracket format")
    func matchBracketYN() {
        let match = matcher.match(line: "Install? [Y/n]", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches [y/N] bracket format")
    func matchBracketYN2() {
        let match = matcher.match(line: "Continue? [y/N]", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    @Test("matches bracket format with ANSI codes")
    func matchBracketWithANSI() {
        let line = "\u{1B}[1mOverwrite? \u{1B}[0m[Y/n]"
        let match = matcher.match(line: line, lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .confirmation)
    }

    // MARK: Continuation Pattern

    @Test("matches Press Enter to continue")
    func matchPressEnter() {
        let match = matcher.match(line: "Press Enter to continue", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .continuation)
        #expect(match?.patternLabel == "Press Enter")
    }

    @Test("matches Press Return to continue")
    func matchPressReturn() {
        let match = matcher.match(line: "Press Return to continue", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .continuation)
    }

    @Test("matches Press Enter case insensitive")
    func matchPressEnterCaseInsensitive() {
        let match = matcher.match(line: "PRESS ENTER TO CONTINUE", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .continuation)
    }

    // MARK: Credential Pattern

    @Test("matches Password colon prompt")
    func matchPassword() {
        let match = matcher.match(line: "Password: ", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
        #expect(match?.patternLabel == "Password prompt")
    }

    @Test("matches password without colon")
    func matchPasswordNoColon() {
        let match = matcher.match(line: "Password", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
    }

    @Test("matches Passphrase colon prompt")
    func matchPassphrase() {
        let match = matcher.match(line: "Passphrase: ", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
    }

    @Test("matches password case insensitive")
    func matchPasswordCaseInsensitive() {
        let match = matcher.match(line: "PASSWORD: ", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
    }

    @Test("matches password with trailing spaces")
    func matchPasswordTrailingSpaces() {
        let match = matcher.match(line: "Password:   ", lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
    }

    @Test("matches password with ANSI codes")
    func matchPasswordWithANSI() {
        let line = "\u{1B}[1;32mPassword\u{1B}[0m: "
        let match = matcher.match(line: line, lineNumber: 0)
        #expect(match != nil)
        #expect(match?.category == .credential)
    }

    // MARK: False Positives and Edge Cases

    @Test("does not match password in middle of line")
    func noMatchPasswordMiddle() {
        // The regex pattern requires password to be followed by optional colon/whitespace and end-of-line
        // So "Password: " at the end matches, but "password in the middle of text" should not
        let match = matcher.match(line: "Enter your password in the field", lineNumber: 0)
        // This may or may not match depending on the actual regex. Let's verify actual behavior:
        // Pattern: (?i)(password|passphrase):?\s*$
        // This requires end-of-line, so "password in the field" won't match.
        #expect(match == nil)
    }

    @Test("does not match grep with password in string")
    func noMatchGrepPassword() {
        let match = matcher.match(line: "grep -r 'password' .", lineNumber: 0)
        // Pattern requires password:?\\s*$ (end of line), so grep won't match
        #expect(match == nil)
    }

    @Test("does not match downloading files")
    func noMatchDownloading() {
        let match = matcher.match(line: "downloading files...", lineNumber: 0)
        #expect(match == nil)
    }

    @Test("does not match system says yes")
    func noMatchSystemSaysYes() {
        let match = matcher.match(line: "The system says yes", lineNumber: 0)
        #expect(match == nil)
    }

    @Test("does not match random text")
    func noMatchRandomText() {
        let match = matcher.match(line: "This is just regular output", lineNumber: 0)
        #expect(match == nil)
    }

    @Test("returns nil for empty line")
    func matchEmptyLine() {
        let match = matcher.match(line: "", lineNumber: 0)
        #expect(match == nil)
    }

    // MARK: Line Number Tracking

    @Test("match preserves correct line number")
    func matchLineNumber() {
        let match = matcher.match(line: "Continue? (y/n)", lineNumber: 42)
        #expect(match?.line == 42)
    }

    @Test("match preserves zero line number")
    func matchLineNumberZero() {
        let match = matcher.match(line: "Password: ", lineNumber: 0)
        #expect(match?.line == 0)
    }

    // MARK: Precedence (Most Specific Pattern Wins)

    @Test("Claude Code pattern takes precedence over generic patterns")
    func claudeCodePrecedence() {
        // "Do you want to run this tool?" matches both "Do you want to" and "Do you want to run"
        // But Claude Code is first in the list, so it should match .claudeCode, not .confirmation
        let match = matcher.match(line: "Do you want to run this tool?", lineNumber: 0)
        #expect(match?.category == .claudeCode)
    }
}

// MARK: - Multi-Line Matching Tests

@Suite("PromptPatternMatcher.matchAll")
struct PromptPatternMatcherMultiLineTests {

    let matcher = PromptPatternMatcher()

    @Test("matchAll detects multiple prompts with correct line numbers")
    func matchAllMultiplePrompts() {
        let lines = [
            "$ ls",
            "file1.txt",
            "Continue? (y/n)",
            "$ cat file1.txt",
            "Password: ",
        ]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 2)
        #expect(matches[0].line == 2)
        #expect(matches[0].category == .confirmation)
        #expect(matches[1].line == 4)
        #expect(matches[1].category == .credential)
    }

    @Test("matchAll returns empty for no matches")
    func matchAllNoMatches() {
        let lines = [
            "$ ls",
            "file1.txt file2.txt",
            "$ echo hello",
        ]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 0)
    }

    @Test("matchAll handles single matching line")
    func matchAllSingleMatch() {
        let lines = ["Install? [Y/n]"]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 1)
        #expect(matches[0].line == 0)
        #expect(matches[0].category == .confirmation)
    }

    @Test("matchAll with empty lines list returns empty")
    func matchAllEmpty() {
        let matches = matcher.matchAll(lines: [])
        #expect(matches.count == 0)
    }

    @Test("matchAll preserves ANSI stripping across lines")
    func matchAllWithANSI() {
        let lines = [
            "$ \u{1B}[1msetup\u{1B}[0m",
            "\u{1B}[32mContinue?\u{1B}[0m (y/n)",
            "\u{1B}[1;31mPassword:\u{1B}[0m ",
        ]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 2)
        #expect(matches[0].line == 1)
        #expect(matches[0].category == .confirmation)
        #expect(matches[1].line == 2)
        #expect(matches[1].category == .credential)
    }

    @Test("matchAll stops at first pattern match per line")
    func matchAllFirstPatternWins() {
        // Line that could match multiple patterns — first compiled pattern should win
        let lines = ["Allow or Deny? (y/n)"]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 1)
        // "Allow or Deny" matches .authorization first, so that wins
        #expect(matches[0].category == .authorization)
    }

    @Test("matchAll with mixed content and prompts")
    func matchAllMixed() {
        let lines = [
            "Setting up environment...",
            "Configure database? [Y/n]",
            "Creating tables...",
            "Press Enter to continue",
            "Done!",
        ]
        let matches = matcher.matchAll(lines: lines)
        #expect(matches.count == 2)
        #expect(matches[0].line == 1)
        #expect(matches[1].line == 3)
    }
}

// MARK: - Matched Text Preservation

@Suite("PromptPatternMatcher.matchedText")
struct PromptPatternMatcherMatchedTextTests {

    let matcher = PromptPatternMatcher()

    @Test("match records the stripped text in matchedText")
    func matchedTextStripped() {
        let line = "\u{1B}[1mContinue? (y/n)\u{1B}[0m"
        let match = matcher.match(line: line, lineNumber: 0)
        #expect(match?.matchedText == "Continue? (y/n)")
    }

    @Test("matchedText reflects full line after ANSI stripping")
    func matchedTextFullLine() {
        let line = "Your input: \u{1B}[32mPassword: \u{1B}[0m"
        let match = matcher.match(line: line, lineNumber: 0)
        #expect(match?.matchedText.contains("Password:") == true)
    }
}

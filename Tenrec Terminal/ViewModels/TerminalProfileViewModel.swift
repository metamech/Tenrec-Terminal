import Foundation
import Observation
import SwiftData

// MARK: - ProfileImportError

enum ProfileImportError: Error, LocalizedError {
    case invalidJSON
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The data is not valid JSON."
        case .missingRequiredField(let field):
            return "The profile JSON is missing required field: \(field)."
        }
    }
}

// MARK: - TerminalProfileViewModel

@Observable
class TerminalProfileViewModel {
    private let modelContext: ModelContext

    /// All profiles in the store (fetched eagerly and kept current).
    var profiles: [TerminalProfile] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshProfiles()
    }

    // MARK: - Default Profile Seeding

    /// Seeds the 4 built-in profiles from bundled JSON files if none exist yet.
    func seedDefaultProfilesIfNeeded() {
        let existing = profiles.filter { $0.isBuiltIn }
        guard existing.isEmpty else { return }

        let fileNames = [
            "tenrec-default",
            "solarized-dark",
            "solarized-light",
            "monokai"
        ]

        for fileName in fileNames {
            guard
                let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "DefaultProfiles"),
                let data = try? Data(contentsOf: url),
                let profile = try? decodeProfile(from: data, forceBuiltIn: true)
            else {
                // Fall back to hard-coded defaults if resource not in bundle
                insertHardcodedDefault(named: fileName)
                continue
            }
            modelContext.insert(profile)
        }

        refreshProfiles()
    }

    // MARK: - CRUD

    /// Creates a new user-editable profile with default values.
    @discardableResult
    func createProfile(name: String) -> TerminalProfile {
        let profile = TerminalProfile(name: name)
        modelContext.insert(profile)
        refreshProfiles()
        return profile
    }

    /// Duplicates an existing profile under "Copy of <name>". The copy is never built-in.
    func duplicateProfile(id: UUID) {
        guard let source = profiles.first(where: { $0.id == id }) else { return }
        let copy = TerminalProfile(
            name: "Copy of \(source.name)",
            fontFamily: source.fontFamily,
            fontSize: source.fontSize,
            foregroundColor: source.foregroundColor,
            backgroundColor: source.backgroundColor,
            cursorColor: source.cursorColor,
            cursorStyle: source.cursorStyle,
            selectionColor: source.selectionColor,
            ansiColors: source.ansiColors,
            opacity: source.opacity,
            isBuiltIn: false
        )
        modelContext.insert(copy)
        refreshProfiles()
    }

    /// Deletes a non-built-in profile. Built-in profiles are protected and silently ignored.
    func deleteProfile(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        guard !profile.isBuiltIn else { return }
        modelContext.delete(profile)
        refreshProfiles()
    }

    /// Updates any subset of profile fields identified by the provided parameters.
    func updateProfile(
        id: UUID,
        name: String? = nil,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        foregroundColor: String? = nil,
        backgroundColor: String? = nil,
        cursorColor: String? = nil,
        cursorStyle: String? = nil,
        selectionColor: String? = nil,
        ansiColors: [String]? = nil,
        opacity: Double? = nil
    ) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        if let v = name           { profile.name = v }
        if let v = fontFamily     { profile.fontFamily = v }
        if let v = fontSize       { profile.fontSize = v }
        if let v = foregroundColor{ profile.foregroundColor = v }
        if let v = backgroundColor{ profile.backgroundColor = v }
        if let v = cursorColor    { profile.cursorColor = v }
        if let v = cursorStyle    { profile.cursorStyle = v }
        if let v = selectionColor { profile.selectionColor = v }
        if let v = ansiColors     { profile.ansiColors = v }
        if let v = opacity        { profile.opacity = v }
    }

    // MARK: - Export / Import

    /// Encodes a profile to JSON. Returns nil if the id is not found.
    func exportProfile(id: UUID) -> Data? {
        guard let profile = profiles.first(where: { $0.id == id }) else { return nil }
        let dto = ProfileDTO(from: profile)
        return try? JSONEncoder().encode(dto)
    }

    /// Decodes a profile from JSON and inserts it. Throws on invalid data or missing fields.
    func importProfile(data: Data) throws {
        let profile = try decodeProfile(from: data, forceBuiltIn: false)
        modelContext.insert(profile)
        refreshProfiles()
    }

    // MARK: - Default Profile Resolution

    /// Returns the profile to use for a session. Falls back to the first built-in.
    func profile(for session: TerminalSession) -> TerminalProfile? {
        if let pid = session.profileId, let match = profiles.first(where: { $0.id == pid }) {
            return match
        }
        return profiles.first(where: { $0.isBuiltIn }) ?? profiles.first
    }

    // MARK: - Private

    private func refreshProfiles() {
        let descriptor = FetchDescriptor<TerminalProfile>(
            sortBy: [SortDescriptor(\.name)]
        )
        profiles = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func decodeProfile(from data: Data, forceBuiltIn: Bool) throws -> TerminalProfile {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProfileImportError.invalidJSON
        }
        guard let name = json["name"] as? String else {
            throw ProfileImportError.missingRequiredField("name")
        }
        let fontFamily     = json["fontFamily"]     as? String  ?? "Menlo"
        let fontSize       = json["fontSize"]       as? Double  ?? 13.0
        let foreground     = json["foregroundColor"] as? String ?? "#C7C7C7"
        let background     = json["backgroundColor"] as? String ?? "#1E1E1E"
        let cursorColor    = json["cursorColor"]    as? String  ?? "#C7C7C7"
        let cursorStyle    = json["cursorStyle"]    as? String  ?? "block"
        let selectionColor = json["selectionColor"] as? String  ?? "#4D90FE80"
        let ansiColors     = json["ansiColors"]     as? [String] ?? TerminalProfile.defaultAnsiColors
        let opacity        = json["opacity"]        as? Double  ?? 1.0
        let isBuiltIn      = forceBuiltIn ? true : (json["isBuiltIn"] as? Bool ?? false)

        return TerminalProfile(
            name: name,
            fontFamily: fontFamily,
            fontSize: fontSize,
            foregroundColor: foreground,
            backgroundColor: background,
            cursorColor: cursorColor,
            cursorStyle: cursorStyle,
            selectionColor: selectionColor,
            ansiColors: ansiColors,
            opacity: opacity,
            isBuiltIn: isBuiltIn
        )
    }

    /// Hard-coded fallback profiles used when JSON bundle resources are unavailable (e.g. in test targets).
    private func insertHardcodedDefault(named fileName: String) {
        let profile: TerminalProfile
        switch fileName {
        case "tenrec-default":
            profile = TerminalProfile(
                name: "Tenrec Default",
                fontFamily: "Menlo", fontSize: 13.0,
                foregroundColor: "#C7C7C7", backgroundColor: "#1E1E1E",
                cursorColor: "#C7C7C7", cursorStyle: "block",
                selectionColor: "#4D90FE80",
                ansiColors: TerminalProfile.defaultAnsiColors,
                opacity: 1.0, isBuiltIn: true
            )
        case "solarized-dark":
            profile = TerminalProfile(
                name: "Solarized Dark",
                fontFamily: "Menlo", fontSize: 13.0,
                foregroundColor: "#839496", backgroundColor: "#002B36",
                cursorColor: "#839496", cursorStyle: "block",
                selectionColor: "#073642CC",
                ansiColors: [
                    "#073642","#DC322F","#859900","#B58900",
                    "#268BD2","#D33682","#2AA198","#EEE8D5",
                    "#002B36","#CB4B16","#586E75","#657B83",
                    "#839496","#6C71C4","#93A1A1","#FDF6E3"
                ],
                opacity: 1.0, isBuiltIn: true
            )
        case "solarized-light":
            profile = TerminalProfile(
                name: "Solarized Light",
                fontFamily: "Menlo", fontSize: 13.0,
                foregroundColor: "#657B83", backgroundColor: "#FDF6E3",
                cursorColor: "#657B83", cursorStyle: "block",
                selectionColor: "#EEE8D5CC",
                ansiColors: [
                    "#073642","#DC322F","#859900","#B58900",
                    "#268BD2","#D33682","#2AA198","#EEE8D5",
                    "#002B36","#CB4B16","#586E75","#657B83",
                    "#839496","#6C71C4","#93A1A1","#FDF6E3"
                ],
                opacity: 1.0, isBuiltIn: true
            )
        case "monokai":
            profile = TerminalProfile(
                name: "Monokai",
                fontFamily: "Menlo", fontSize: 13.0,
                foregroundColor: "#F8F8F2", backgroundColor: "#272822",
                cursorColor: "#F8F8F2", cursorStyle: "block",
                selectionColor: "#49483E99",
                ansiColors: [
                    "#272822","#F92672","#A6E22E","#F4BF75",
                    "#66D9EF","#AE81FF","#A1EFE4","#F8F8F2",
                    "#75715E","#F92672","#A6E22E","#F4BF75",
                    "#66D9EF","#AE81FF","#A1EFE4","#F9F8F5"
                ],
                opacity: 1.0, isBuiltIn: true
            )
        default:
            return
        }
        modelContext.insert(profile)
    }
}

// MARK: - ProfileDTO (Codable transfer object for export/import)

struct ProfileDTO: Codable {
    var name: String
    var fontFamily: String
    var fontSize: Double
    var foregroundColor: String
    var backgroundColor: String
    var cursorColor: String
    var cursorStyle: String
    var selectionColor: String
    var ansiColors: [String]
    var opacity: Double

    init(from profile: TerminalProfile) {
        self.name = profile.name
        self.fontFamily = profile.fontFamily
        self.fontSize = profile.fontSize
        self.foregroundColor = profile.foregroundColor
        self.backgroundColor = profile.backgroundColor
        self.cursorColor = profile.cursorColor
        self.cursorStyle = profile.cursorStyle
        self.selectionColor = profile.selectionColor
        self.ansiColors = profile.ansiColors
        self.opacity = profile.opacity
    }
}

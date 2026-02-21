import Foundation
import Testing
import SwiftData
@testable import Tenrec_Terminal

// MARK: - Helpers

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([TerminalSession.self, TerminalProfile.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

// MARK: - TerminalProfile Model Tests

@Suite("TerminalProfile Model")
struct TerminalProfileModelTests {

    @Test("TerminalProfile initializes with expected defaults")
    func profileDefaultValues() throws {
        let profile = TerminalProfile(name: "Test")
        #expect(profile.name == "Test")
        #expect(profile.fontFamily == "Menlo")
        #expect(profile.fontSize == 13.0)
        #expect(profile.cursorStyle == "block")
        #expect(profile.opacity == 1.0)
        #expect(profile.isBuiltIn == false)
        #expect(profile.ansiColors.count == 16)
    }

    @Test("TerminalProfile ansiColors has exactly 16 entries by default")
    func profileAnsiColorsCount() throws {
        let profile = TerminalProfile(name: "Test")
        #expect(profile.ansiColors.count == 16)
    }

    @Test("TerminalProfile can be inserted into SwiftData context")
    func profileSwiftDataInsertion() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let profile = TerminalProfile(name: "MyProfile")
        context.insert(profile)

        let descriptor = FetchDescriptor<TerminalProfile>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].name == "MyProfile")
    }
}

// MARK: - TerminalProfileViewModel Tests

@Suite("TerminalProfileViewModel")
struct TerminalProfileViewModelTests {

    // MARK: Seeding

    @Test("seedDefaultProfiles inserts exactly 4 built-in profiles")
    func seedDefaultProfilesCount() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.seedDefaultProfilesIfNeeded()

        #expect(vm.profiles.count == 4)
    }

    @Test("seedDefaultProfiles does not duplicate profiles on second call")
    func seedDefaultProfilesIdempotent() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.seedDefaultProfilesIfNeeded()
        vm.seedDefaultProfilesIfNeeded()

        #expect(vm.profiles.count == 4)
    }

    @Test("seeded profiles include Tenrec Default, Solarized Dark, Solarized Light, Monokai")
    func seedDefaultProfileNames() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.seedDefaultProfilesIfNeeded()

        let names = Set(vm.profiles.map { $0.name })
        #expect(names.contains("Tenrec Default"))
        #expect(names.contains("Solarized Dark"))
        #expect(names.contains("Solarized Light"))
        #expect(names.contains("Monokai"))
    }

    @Test("seeded built-in profiles have isBuiltIn = true")
    func seedDefaultProfilesAreBuiltIn() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.seedDefaultProfilesIfNeeded()

        let allBuiltIn = vm.profiles.allSatisfy { $0.isBuiltIn }
        #expect(allBuiltIn)
    }

    // MARK: createProfile

    @Test("createProfile adds a new non-built-in profile")
    func createProfileAddsProfile() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "My Custom")

        #expect(vm.profiles.count == 1)
        #expect(vm.profiles[0].name == "My Custom")
        #expect(vm.profiles[0].isBuiltIn == false)
    }

    // MARK: duplicateProfile

    @Test("duplicateProfile creates copy with 'Copy of ...' name")
    func duplicateProfileName() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "Original")
        let original = try #require(vm.profiles.first)

        vm.duplicateProfile(id: original.id)

        #expect(vm.profiles.count == 2)
        let copy = try #require(vm.profiles.first(where: { $0.name != "Original" }))
        #expect(copy.name == "Copy of Original")
        #expect(copy.isBuiltIn == false)
    }

    @Test("duplicateProfile copies font and color values")
    func duplicateProfileCopiesValues() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "Source")
        let original = try #require(vm.profiles.first)
        vm.updateProfile(id: original.id, fontFamily: "Monaco", fontSize: 16.0)

        vm.duplicateProfile(id: original.id)

        let copy = try #require(vm.profiles.first(where: { $0.name != "Source" }))
        #expect(copy.fontFamily == "Monaco")
        #expect(copy.fontSize == 16.0)
    }

    // MARK: deleteProfile

    @Test("deleteProfile removes a non-built-in profile")
    func deleteNonBuiltInProfile() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "Deletable")
        let profile = try #require(vm.profiles.first)

        vm.deleteProfile(id: profile.id)

        #expect(vm.profiles.isEmpty)
    }

    @Test("deleteProfile does not remove a built-in profile")
    func deleteBuiltInProfileIsNoop() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.seedDefaultProfilesIfNeeded()
        let builtIn = try #require(vm.profiles.first(where: { $0.isBuiltIn }))
        let countBefore = vm.profiles.count

        vm.deleteProfile(id: builtIn.id)

        #expect(vm.profiles.count == countBefore)
    }

    // MARK: updateProfile

    @Test("updateProfile changes font family and size")
    func updateProfileFont() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "Editable")
        let profile = try #require(vm.profiles.first)

        vm.updateProfile(id: profile.id, fontFamily: "Courier New", fontSize: 14.0)

        #expect(profile.fontFamily == "Courier New")
        #expect(profile.fontSize == 14.0)
    }

    @Test("updateProfile changes cursor style")
    func updateProfileCursorStyle() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "CursorTest")
        let profile = try #require(vm.profiles.first)

        vm.updateProfile(id: profile.id, cursorStyle: "underline")

        #expect(profile.cursorStyle == "underline")
    }

    @Test("updateProfile changes foreground and background colors")
    func updateProfileColors() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "ColorTest")
        let profile = try #require(vm.profiles.first)

        vm.updateProfile(id: profile.id, foregroundColor: "#FFFFFF", backgroundColor: "#000000")

        #expect(profile.foregroundColor == "#FFFFFF")
        #expect(profile.backgroundColor == "#000000")
    }

    // MARK: exportProfile / importProfile

    @Test("exportProfile produces valid JSON data")
    func exportProfileProducesJSON() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "Exportable")
        let profile = try #require(vm.profiles.first)

        let data = try #require(vm.exportProfile(id: profile.id))
        #expect(!data.isEmpty)

        // Must be parseable as JSON
        let json = try #require(try? JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "Exportable")
    }

    @Test("importProfile round-trip preserves all fields")
    func importProfileRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        vm.createProfile(name: "RoundTrip")
        let profile = try #require(vm.profiles.first)
        vm.updateProfile(id: profile.id, fontFamily: "Monaco", fontSize: 15.0, cursorStyle: "bar")

        let data = try #require(vm.exportProfile(id: profile.id))

        // Delete original then import
        vm.deleteProfile(id: profile.id)
        #expect(vm.profiles.isEmpty)

        try vm.importProfile(data: data)

        let imported = try #require(vm.profiles.first)
        #expect(imported.name == "RoundTrip")
        #expect(imported.fontFamily == "Monaco")
        #expect(imported.fontSize == 15.0)
        #expect(imported.cursorStyle == "bar")
        // Imported profiles are not built-in
        #expect(imported.isBuiltIn == false)
    }

    @Test("importProfile fails gracefully with invalid JSON")
    func importProfileInvalidJSON() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        let badData = Data("not valid json {{{".utf8)

        #expect(throws: (any Error).self) {
            try vm.importProfile(data: badData)
        }
        #expect(vm.profiles.isEmpty)
    }

    @Test("importProfile fails gracefully with missing required fields")
    func importProfileMissingFields() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let vm = TerminalProfileViewModel(modelContext: context)

        // JSON missing 'name' field
        let incompleteJSON = Data("""
        {"fontFamily": "Menlo", "fontSize": 13.0}
        """.utf8)

        #expect(throws: (any Error).self) {
            try vm.importProfile(data: incompleteJSON)
        }
        #expect(vm.profiles.isEmpty)
    }
}

// MARK: - TerminalSession profileId Tests

@Suite("TerminalSession profileId")
struct TerminalSessionProfileIdTests {

    @Test("TerminalSession defaults profileId to nil")
    func sessionProfileIdDefaultsNil() throws {
        let session = TerminalSession(name: "Test")
        #expect(session.profileId == nil)
    }

    @Test("TerminalSession can assign a profileId")
    func sessionProfileIdAssignment() throws {
        let session = TerminalSession(name: "Test")
        let id = UUID()
        session.profileId = id
        #expect(session.profileId == id)
    }
}

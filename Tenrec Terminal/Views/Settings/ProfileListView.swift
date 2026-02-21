import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ProfileListView

/// Master-detail profile list for the Preferences window.
/// Left: list of profiles with add/remove/duplicate toolbar buttons.
/// Right: ProfileEditorView for the selected profile.
struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var profileViewModel: TerminalProfileViewModel?

    @State private var selectedProfileId: UUID?
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var exportData: Data?
    @State private var alertMessage: String?
    @State private var showAlert = false

    var body: some View {
        Group {
            if let vm = profileViewModel {
                profileContent(vm: vm)
            } else {
                ProgressView("Loading profiles…")
                    .onAppear {
                        profileViewModel = TerminalProfileViewModel(modelContext: modelContext)
                        profileViewModel?.seedDefaultProfilesIfNeeded()
                        selectedProfileId = profileViewModel?.profiles.first?.id
                    }
            }
        }
        .alert("Profile Error", isPresented: $showAlert, presenting: alertMessage) { _ in
            Button("OK") {}
        } message: { msg in
            Text(msg)
        }
    }

    @ViewBuilder
    private func profileContent(vm: TerminalProfileViewModel) -> some View {
        NavigationSplitView {
            List(vm.profiles, selection: $selectedProfileId) { profile in
                HStack {
                    Image(systemName: "terminal")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name)
                            .lineLimit(1)
                        if profile.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tag(profile.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: { vm.createProfile(name: "New Profile") }) {
                        Image(systemName: "plus")
                    }
                    .help("New Profile")

                    Button(action: {
                        guard let id = selectedProfileId else { return }
                        vm.duplicateProfile(id: id)
                    }) {
                        Image(systemName: "plus.square.on.square")
                    }
                    .help("Duplicate Profile")
                    .disabled(selectedProfileId == nil)

                    Button(role: .destructive, action: {
                        guard let id = selectedProfileId else { return }
                        let isBuiltIn = vm.profiles.first(where: { $0.id == id })?.isBuiltIn ?? false
                        if isBuiltIn {
                            alertMessage = "Built-in profiles cannot be deleted. Duplicate the profile first to customize it."
                            showAlert = true
                        } else {
                            vm.deleteProfile(id: id)
                            selectedProfileId = vm.profiles.first?.id
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                    .help("Delete Profile")
                    .disabled(selectedProfileId == nil)
                }

                ToolbarItemGroup(placement: .automatic) {
                    Button(action: {
                        guard let id = selectedProfileId,
                              let data = vm.exportProfile(id: id) else { return }
                        exportData = data
                        showExportPicker = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export Profile")
                    .disabled(selectedProfileId == nil)

                    Button(action: { showImportPicker = true }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import Profile")
                }
            }
        } detail: {
            if let id = selectedProfileId,
               let profile = vm.profiles.first(where: { $0.id == id }) {
                ProfileEditorView(profile: profile, viewModel: vm)
            } else {
                ContentUnavailableView(
                    "No Profile Selected",
                    systemImage: "paintbrush",
                    description: Text("Select a profile from the list to edit it.")
                )
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first,
                      url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    do {
                        try vm.importProfile(data: data)
                        selectedProfileId = vm.profiles.last?.id
                    } catch {
                        alertMessage = "Failed to import profile: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            case .failure(let error):
                alertMessage = "Could not open file: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .fileExporter(
            isPresented: $showExportPicker,
            document: JSONDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: profileName(for: selectedProfileId, in: vm) + ".json"
        ) { result in
            if case .failure(let error) = result {
                alertMessage = "Export failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func profileName(for id: UUID?, in vm: TerminalProfileViewModel) -> String {
        guard let id else { return "profile" }
        return vm.profiles.first(where: { $0.id == id })?.name ?? "profile"
    }
}

// MARK: - JSONDocument (for fileExporter)

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    ProfileListView()
        .modelContainer(for: [TerminalSession.self, TerminalProfile.self], inMemory: true)
        .frame(width: 700, height: 500)
}

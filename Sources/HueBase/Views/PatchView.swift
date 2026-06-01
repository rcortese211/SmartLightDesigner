import SwiftUI

struct PatchView: View {
    @Environment(AppState.self) private var appState
    @State private var showAddFixture = false
    @State private var editingFixture: Fixture?

    var body: some View {
        @Bindable var state = appState
        HSplitView {
            fixtureTable
            if let fixture = editingFixture {
                FixtureEditorView(fixture: binding(for: fixture))
                    .frame(minWidth: 280, maxWidth: 360)
            }
        }
        .navigationTitle("Patch")
        .background(SmartLightTheme.background)
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showAddFixture = true }) {
                    Label("Add Fixture", systemImage: "plus")
                }
                Button(action: deleteSelected) {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(appState.selectedFixtureIDs.isEmpty)
            }
        }
        .sheet(isPresented: $showAddFixture) {
            AddFixtureSheet()
        }
    }

    private var fixtureTable: some View {
        @Bindable var state = appState
        return Table(appState.show.fixtures, selection: $state.selectedFixtureIDs) {
            TableColumn("Name") { fixture in
                Text(fixture.name)
                    .onTapGesture(count: 2) { editingFixture = fixture }
            }
            TableColumn("Profile") { fixture in
                Text(appState.show.profile(for: fixture)?.name ?? "Unknown")
                    .foregroundStyle(.secondary)
            }
            TableColumn("Universe") { fixture in
                Text("\(fixture.universe + 1)")
            }
            .width(70)
            TableColumn("Address") { fixture in
                Text("\(fixture.startAddress)")
            }
            .width(70)
            TableColumn("Channels") { fixture in
                Text("\(appState.show.profile(for: fixture)?.channelCount ?? 0)")
            }
            .width(70)
            TableColumn("Notes") { fixture in
                Text(fixture.notes).foregroundStyle(.tertiary)
            }
        }
        .onChange(of: appState.selectedFixtureIDs) { _, newIDs in
            if let first = newIDs.first {
                editingFixture = appState.show.fixtures.first(where: { $0.id == first })
            }
        }
    }

    private func binding(for fixture: Fixture) -> Binding<Fixture> {
        Binding(
            get: { appState.show.fixtures.first(where: { $0.id == fixture.id }) ?? fixture },
            set: { newValue in
                if let idx = appState.show.fixtures.firstIndex(where: { $0.id == fixture.id }) {
                    appState.show.fixtures[idx] = newValue
                }
            }
        )
    }

    private func deleteSelected() {
        appState.show.fixtures.removeAll { appState.selectedFixtureIDs.contains($0.id) }
        appState.selectedFixtureIDs = []
        editingFixture = nil
    }
}

struct AddFixtureSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedProfileId: UUID?
    @State private var universe = 0
    @State private var startAddress = 1
    @State private var count = 1

    var body: some View {
        Form {
            Section("Fixture") {
                TextField("Name", text: $name)
                Picker("Profile", selection: $selectedProfileId) {
                    ForEach(appState.show.fixtureProfiles) { profile in
                        Text("\(profile.manufacturer) – \(profile.name)").tag(Optional(profile.id))
                    }
                }
            }
            Section("DMX Addressing") {
                Stepper("Universe: \(universe + 1)", value: $universe, in: 0...255)
                Stepper("Start Address: \(startAddress)", value: $startAddress, in: 1...512)
                Stepper("Count: \(count)", value: $count, in: 1...64)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add") { addFixtures(); dismiss() }
                    .disabled(name.isEmpty || selectedProfileId == nil)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear { selectedProfileId = appState.show.fixtureProfiles.first?.id }
    }

    private func addFixtures() {
        guard let profileId = selectedProfileId,
              let profile = appState.show.fixtureProfiles.first(where: { $0.id == profileId })
        else { return }

        for i in 0..<count {
            let addr = startAddress + i * profile.channelCount
            guard addr <= 512 else { break }
            let fixtureName = count > 1 ? "\(name) \(i + 1)" : name
            let x = Double(appState.show.fixtures.count + i) / max(1, Double(appState.show.fixtures.count + count))
            appState.show.fixtures.append(
                Fixture(name: fixtureName, profileId: profileId,
                        universe: universe, startAddress: addr,
                        positionX: x, positionY: 0.5)
            )
        }
    }
}

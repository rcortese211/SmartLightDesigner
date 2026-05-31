import SwiftUI

struct FixtureEditorView: View {
    @Binding var fixture: Fixture
    @Environment(AppState.self) private var appState
    @State private var showProfileEditor = false

    var profile: FixtureProfile? {
        appState.show.profile(for: fixture)
    }

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Name") {
                    TextField("Name", text: $fixture.name)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Profile") {
                    HStack {
                        Picker("", selection: $fixture.profileId) {
                            ForEach(appState.show.fixtureProfiles) { p in
                                Text("\(p.name)").tag(p.id)
                            }
                        }
                        .labelsHidden()
                        Button("Edit") { showProfileEditor = true }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Section("DMX Address") {
                LabeledContent("Universe") {
                    TextField("", value: $fixture.universe, formatter: NumberFormatter())
                        .frame(width: 60)
                }
                LabeledContent("Start Address") {
                    Stepper("\(fixture.startAddress)", value: $fixture.startAddress, in: 1...512)
                }
                if let prof = profile {
                    LabeledContent("End Address") {
                        Text("\(fixture.startAddress + prof.channelCount - 1)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Visualizer Position") {
                LabeledContent("X") {
                    Slider(value: $fixture.positionX, in: 0...1)
                }
                LabeledContent("Y") {
                    Slider(value: $fixture.positionY, in: 0...1)
                }
            }

            if let prof = profile {
                Section("Channels (\(prof.channelCount))") {
                    ForEach(prof.channels) { ch in
                        HStack {
                            Text("\(fixture.startAddress + ch.offset)").monospacedDigit().frame(width: 36)
                            Text(ch.name).foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }

            Section {
                TextField("Notes", text: $fixture.notes, axis: .vertical)
                    .lineLimit(3)
            } header: {
                Text("Notes")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showProfileEditor) {
            if let profile {
                ProfileEditorView(profile: profileBinding(profile))
            }
        }
    }

    private func profileBinding(_ profile: FixtureProfile) -> Binding<FixtureProfile> {
        Binding(
            get: { appState.show.fixtureProfiles.first(where: { $0.id == profile.id }) ?? profile },
            set: { newValue in
                if let idx = appState.show.fixtureProfiles.firstIndex(where: { $0.id == profile.id }) {
                    appState.show.fixtureProfiles[idx] = newValue
                }
            }
        )
    }
}

struct ProfileEditorView: View {
    @Binding var profile: FixtureProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $profile.name)
                TextField("Manufacturer", text: $profile.manufacturer)
            }
            Section("Channels") {
                ForEach($profile.channels) { $channel in
                    HStack {
                        Text("\(channel.offset + 1)").monospacedDigit().frame(width: 28)
                        TextField("Channel Name", text: $channel.name)
                    }
                }
                .onDelete { profile.channels.remove(atOffsets: $0) }
                .onMove { profile.channels.move(fromOffsets: $0, toOffset: $1) }

                Button("Add Channel") {
                    let offset = profile.channels.count
                    profile.channels.append(
                        FixtureChannel(id: UUID(), name: "Channel \(offset + 1)", offset: offset, defaultValue: 0)
                    )
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .frame(width: 380, height: 500)
    }
}

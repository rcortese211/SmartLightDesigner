import SwiftUI

// Three-panel layout:  [Folders] | [Palettes] | [Layer Stack + Editor]
struct EffectsView: View {
    @Environment(AppState.self) private var appState

    @State private var showAddFolder = false
    @State private var showAddPalette = false

    // Selection state lives in AppState so it survives tab navigation.
    private var selectedFolderID: UUID? {
        get { appState.effectsSelectedFolderID }
        nonmutating set { appState.effectsSelectedFolderID = newValue }
    }
    private var selectedPaletteID: UUID? {
        get { appState.effectsSelectedPaletteID }
        nonmutating set { appState.effectsSelectedPaletteID = newValue }
    }
    private var selectedLayerID: UUID? {
        get { appState.effectsSelectedLayerID }
        nonmutating set { appState.effectsSelectedLayerID = newValue }
    }

    var body: some View {
        @Bindable var appState = appState
        HSplitView {
            folderColumn
                .frame(minWidth: 150, maxWidth: 260)
            paletteColumn
                .frame(minWidth: 180, maxWidth: 320)
            layerColumn
        }
        .navigationTitle("Effects")
        .onAppear { autoSelectIfNeeded() }
        .toolbar {
            ToolbarItemGroup { }
        }
        .sheet(isPresented: $showAddFolder) { AddFolderSheet(isPresented: $showAddFolder) }
        .sheet(isPresented: $showAddPalette) {
            AddPaletteSheet(isPresented: $showAddPalette, folderID: selectedFolderID)
        }
    }

    // MARK: - Folder Column

    private var folderColumn: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Folders")
            List(selection: $appState.effectsSelectedFolderID) {
                ForEach(appState.show.effectFolders) { folder in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(SmartLightTheme.purple.opacity(0.7))
                        Text(folder.name)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Spacer()
                        Text("\(folder.palettes.count)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .padding(.vertical, 3)
                    .tag(folder.id)
                    .contextMenu {
                        Button("Rename…") { renameFolder(folder) }
                        Divider()
                        Button("Delete Folder", role: .destructive) { deleteFolder(folder) }
                    }
                }
                .onMove { appState.show.effectFolders.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SmartLightTheme.surface)

            Divider().background(SmartLightTheme.border)
            HStack {
                Button(action: { showAddFolder = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SmartLightTheme.purple)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SmartLightTheme.surfaceHigh)
        }
        .background(SmartLightTheme.surface)
    }

    // MARK: - Palette Column

    private var paletteColumn: some View {
        VStack(spacing: 0) {
            PanelHeader(title: selectedFolder?.name ?? "Palettes")

            if let folder = selectedFolder {
                List(selection: $appState.effectsSelectedPaletteID) {
                    ForEach(folder.palettes) { palette in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(palette.name)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                if palette.id == appState.recalledPaletteIDOnA {
                                    Text("A")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(SmartLightTheme.active)
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(SmartLightTheme.active.opacity(0.18))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                if palette.id == appState.recalledPaletteIDOnB {
                                    Text("B")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(SmartLightTheme.purple)
                                        .padding(.horizontal, 6).padding(.vertical, 3)
                                        .background(SmartLightTheme.purple.opacity(0.18))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Text("\(palette.layers.count) layer\(palette.layers.count == 1 ? "" : "s")")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color(white: 0.38))
                        }
                        .padding(.vertical, 4)
                        .tag(palette.id)
                        .contextMenu {
                            Button("Rename…") { renamePalette(palette, in: folder) }
                            Button("Duplicate") { duplicatePalette(palette, in: folder) }
                            Divider()
                            Button("Store Live Stack Here") { storeLiveToPalette(palette, in: folder) }
                            Button("Recall to Program A") { recallPalette(palette) }
                            Button("Recall to Program B") { recallPaletteToBDeck(palette) }
                            Divider()
                            Menu("Add to Timeline Track…") {
                                ForEach(Array(appState.show.timeline.tracks.enumerated()), id: \.element.id) { idx, track in
                                    Button(track.name) { addPaletteToTimeline(palette, trackIndex: idx) }
                                }
                                if appState.show.timeline.tracks.isEmpty {
                                    Text("No tracks — add one in the Timeline tab")
                                        .foregroundStyle(.secondary)
                                }
                                Divider()
                                Button("New Track") {
                                    let idx = appState.show.timeline.tracks.count
                                    appState.show.timeline.tracks.append(TimelineTrack(name: "Track \(idx + 1)"))
                                    addPaletteToTimeline(palette, trackIndex: idx)
                                }
                            }
                            Divider()
                            Button("Delete Palette", role: .destructive) { deletePalette(palette, from: folder) }
                        }
                        .onTapGesture(count: 2) { recallPalette(palette) }
                        .draggable(PaletteTransfer(paletteID: palette.id,
                                                   paletteName: palette.name,
                                                   layers: palette.layers))
                    }
                    .onMove { indices, dest in movePalette(in: folder, from: indices, to: dest) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SmartLightTheme.surface)
            } else {
                VStack {
                    Spacer()
                    Text("Select a folder")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(SmartLightTheme.surface)
            }

            Divider().background(SmartLightTheme.border)
            HStack {
                Button(action: { showAddPalette = true }) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SmartLightTheme.purple)
                .disabled(selectedFolderID == nil)

                Spacer()

                if selectedPaletteID != nil {
                    Button(action: recallSelectedPalette) {
                        Text("→ A")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(SmartLightTheme.active)
                    }
                    .buttonStyle(.plain)
                    Button(action: recallSelectedPaletteToB) {
                        Text("→ B")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(SmartLightTheme.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SmartLightTheme.surfaceHigh)
        }
        .background(SmartLightTheme.surface)
    }

    // MARK: - Layer Stack Column (palette content + editor)

    private var layerColumn: some View {
        HSplitView {
            paletteLayerStack
                .frame(minWidth: 100, maxWidth: 180)
            if let binding = selectedLayerBinding {
                LayerEditorView(layer: binding)
            } else {
                emptyEditorState
            }
        }
    }

    private var emptyEditorState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(SmartLightTheme.purple.opacity(0.3))
            Text("SELECT AN EFFECT LAYER")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.25))
                .kerning(1)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SmartLightTheme.background)
    }

    private var selectedLayerBinding: Binding<Layer>? {
        guard let layerID = selectedLayerID,
              let (fi, pi, li) = findLayer(layerID) else { return nil }
        return layerBinding(folderIdx: fi, paletteIdx: pi, layerIdx: li)
    }

    private var paletteLayerStack: some View {
        VStack(spacing: 0) {
            if let palette = selectedPalette {
                PanelHeader(title: palette.name)
                List(selection: $appState.effectsSelectedLayerID) {
                    ForEach(palette.layers) { layer in
                        if let binding = rowLayerBinding(for: layer.id) {
                            LayerRowView(layer: binding)
                                .tag(layer.id)
                        }
                    }
                    .onMove { if let (fi, pi) = findPalette() { movePaletteLayer(fi: fi, pi: pi, from: $0, to: $1) } }
                    .onDelete { if let (fi, pi) = findPalette() { deletePaletteLayer(fi: fi, pi: pi, at: $0) } }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SmartLightTheme.surface)

                Divider().background(SmartLightTheme.border)
                HStack {
                    Button(action: addLayerToPalette) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SmartLightTheme.purple)

                    Spacer()

                    Button(action: recallSelectedPalette) {
                        Text("RECALL → A")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(SmartLightTheme.active)
                    }
                    .buttonStyle(.plain)
                    Button(action: recallSelectedPaletteToB) {
                        Text("→ B")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(SmartLightTheme.purple)
                    }
                    .buttonStyle(.plain)
                    Divider().frame(height: 14)
                    Button(action: storeLiveAsNewPalette) {
                        Text("STORE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(SmartLightTheme.purple.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedFolderID == nil)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(SmartLightTheme.surfaceHigh)
            } else {
                PanelHeader(title: "Effect Layers")
                VStack {
                    Spacer()
                    Text("Select a palette")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(SmartLightTheme.surface)
            }
        }
        .background(SmartLightTheme.surface)
    }

    // MARK: - Computed helpers

    private func rowLayerBinding(for layerID: UUID) -> Binding<Layer>? {
        guard let (fi, pi, li) = findLayer(layerID) else { return nil }
        return layerBinding(folderIdx: fi, paletteIdx: pi, layerIdx: li)
    }

    private var selectedFolder: EffectFolder? {
        appState.show.effectFolders.first(where: { $0.id == selectedFolderID })
    }

    private var selectedPalette: EffectPalette? {
        guard let folder = selectedFolder else { return nil }
        return folder.palettes.first(where: { $0.id == selectedPaletteID })
    }

    private func findPalette() -> (Int, Int)? {
        guard let fid = selectedFolderID, let pid = selectedPaletteID else { return nil }
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == fid }),
              let pi = appState.show.effectFolders[fi].palettes.firstIndex(where: { $0.id == pid })
        else { return nil }
        return (fi, pi)
    }

    private func findLayer(_ lid: UUID) -> (Int, Int, Int)? {
        guard let (fi, pi) = findPalette() else { return nil }
        guard let li = appState.show.effectFolders[fi].palettes[pi].layers
            .firstIndex(where: { $0.id == lid }) else { return nil }
        return (fi, pi, li)
    }

    private func layerBinding(folderIdx fi: Int, paletteIdx pi: Int, layerIdx li: Int) -> Binding<Layer> {
        Binding(
            get: { appState.show.effectFolders[fi].palettes[pi].layers[li] },
            set: { newLayer in
                appState.show.effectFolders[fi].palettes[pi].layers[li] = newLayer
                let paletteID = appState.show.effectFolders[fi].palettes[pi].id
                // Mirror to live deck A if this palette is currently recalled there
                if paletteID == appState.recalledPaletteIDOnA,
                   let idx = appState.show.layers.firstIndex(where: { $0.id == newLayer.id }) {
                    appState.show.layers[idx] = newLayer
                }
                // Mirror to live deck B if this palette is currently recalled there
                if paletteID == appState.recalledPaletteIDOnB,
                   let idx = appState.programBLayers.firstIndex(where: { $0.id == newLayer.id }) {
                    appState.programBLayers[idx] = newLayer
                }
            }
        )
    }

    // MARK: - Auto-selection

    private func autoSelectIfNeeded() {
        // Already have a selection — nothing to do
        if selectedFolderID != nil && selectedPaletteID != nil { return }
        guard !appState.show.effectFolders.isEmpty else { return }

        // Prefer the folder/palette that's currently live on deck A, then B
        for activePaletteID in [appState.recalledPaletteIDOnA, appState.recalledPaletteIDOnB].compactMap({ $0 }) {
            for folder in appState.show.effectFolders {
                if folder.palettes.contains(where: { $0.id == activePaletteID }) {
                    selectedFolderID  = folder.id
                    selectedPaletteID = activePaletteID
                    return
                }
            }
        }

        // Fall back to first folder + first palette
        let firstFolder = appState.show.effectFolders[0]
        selectedFolderID  = firstFolder.id
        selectedPaletteID = firstFolder.palettes.first?.id
    }

    // MARK: - Mutations

    private func deleteFolder(_ folder: EffectFolder) {
        appState.show.effectFolders.removeAll { $0.id == folder.id }
        if selectedFolderID == folder.id { selectedFolderID = nil; selectedPaletteID = nil }
    }

    private func renameFolder(_ folder: EffectFolder) {
        guard let idx = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        appState.show.effectFolders[idx].name = "Folder \(idx + 1)"
    }

    private func deletePalette(_ palette: EffectPalette, from folder: EffectFolder) {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        appState.show.effectFolders[fi].palettes.removeAll { $0.id == palette.id }
        if selectedPaletteID == palette.id { selectedPaletteID = nil }
    }

    private func renamePalette(_ palette: EffectPalette, in folder: EffectFolder) {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }),
              let pi = appState.show.effectFolders[fi].palettes.firstIndex(where: { $0.id == palette.id })
        else { return }
        let count = appState.show.effectFolders[fi].palettes.count
        appState.show.effectFolders[fi].palettes[pi].name = "Palette \(count)"
    }

    private func duplicatePalette(_ palette: EffectPalette, in folder: EffectFolder) {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        let copy = EffectPalette(id: UUID(), name: palette.name + " Copy", layers: palette.layers)
        appState.show.effectFolders[fi].palettes.append(copy)
    }

    private func movePalette(in folder: EffectFolder, from: IndexSet, to: Int) {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        appState.show.effectFolders[fi].palettes.move(fromOffsets: from, toOffset: to)
    }

    private func movePaletteLayer(fi: Int, pi: Int, from: IndexSet, to: Int) {
        appState.show.effectFolders[fi].palettes[pi].layers.move(fromOffsets: from, toOffset: to)
    }

    private func deletePaletteLayer(fi: Int, pi: Int, at offsets: IndexSet) {
        appState.show.effectFolders[fi].palettes[pi].layers.remove(atOffsets: offsets)
    }

    private func addLayerToPalette() {
        guard let (fi, pi) = findPalette() else { return }
        let effectId = EffectRegistry.shared.allEffects.first?.id ?? "color_fill"
        let layer = Layer(
            name: "Layer \(appState.show.effectFolders[fi].palettes[pi].layers.count + 1)",
            effectId: effectId,
            parameters: EffectRegistry.shared.defaultParameters(for: effectId)
        )
        appState.show.effectFolders[fi].palettes[pi].layers.append(layer)
        appState.effectsSelectedLayerID = layer.id
    }

    private func recallPalette(_ palette: EffectPalette) {
        appState.show.layers = palette.layers   // keep same IDs so live-edit can mirror by ID
        appState.recalledPaletteIDOnA = palette.id
        appState.statusMessage = "Recalled: \(palette.name)"
    }

    private func recallSelectedPalette() {
        guard let palette = selectedPalette else { return }
        recallPalette(palette)
    }

    private func recallSelectedPaletteToB() {
        guard let palette = selectedPalette else { return }
        recallPaletteToBDeck(palette)
    }

    private func recallPaletteToBDeck(_ palette: EffectPalette) {
        appState.programBLayers = palette.layers   // keep same IDs for live-edit mirroring
        appState.recalledPaletteIDOnB = palette.id
        appState.statusMessage = "B: \(palette.name)"
    }

    private func addPaletteToTimeline(_ palette: EffectPalette, trackIndex: Int) {
        guard trackIndex < appState.show.timeline.tracks.count else { return }
        let t = appState.timelineEngine.playheadTime
        let clip = TimelineClip(
            startTime: max(0, t),
            layers: palette.layers,
            label: palette.name,
            colorHue: Double.random(in: 0...1)
        )
        appState.show.timeline.tracks[trackIndex].clips.append(clip)
    }

    private func storeLiveAsNewPalette() {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == selectedFolderID }) else { return }
        let count = appState.show.effectFolders[fi].palettes.count + 1
        let palette = EffectPalette(name: "Palette \(count)", layers: appState.show.layers)
        appState.show.effectFolders[fi].palettes.append(palette)
        selectedPaletteID = palette.id
        appState.statusMessage = "Stored as: Palette \(count)"
    }

    private func storeLiveToPalette(_ palette: EffectPalette, in folder: EffectFolder) {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folder.id }),
              let pi = appState.show.effectFolders[fi].palettes.firstIndex(where: { $0.id == palette.id })
        else { return }
        appState.show.effectFolders[fi].palettes[pi].layers = appState.show.layers
        appState.statusMessage = "Stored to: \(palette.name)"
    }
}

// MARK: - Layer Row (compact)

struct LayerRowView: View {
    @Binding var layer: Layer

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $layer.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .scaleEffect(0.85)
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .strikethrough(!layer.isEnabled)
                    .foregroundStyle(layer.isEnabled ? .primary : .secondary)
                Text(EffectRegistry.shared.effect(for: layer.effectId)?.name ?? layer.effectId)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(SmartLightTheme.purple.opacity(0.7))
            }
            Spacer()
            Text("\(Int(layer.opacity * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Add Folder Sheet

struct AddFolderSheet: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            PanelHeader(title: "New Folder")
            VStack(spacing: 12) {
                TextField("Folder name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                HStack {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Create") {
                        appState.show.effectFolders.append(EffectFolder(name: name.isEmpty ? "New Folder" : name))
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SmartLightTheme.purple)
                    .disabled(name.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(SmartLightTheme.surface)
    }
}

// MARK: - Add Palette Sheet

struct AddPaletteSheet: View {
    @Binding var isPresented: Bool
    let folderID: UUID?
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var copyLiveLayers = false

    var body: some View {
        VStack(spacing: 16) {
            PanelHeader(title: "New Palette")
            VStack(spacing: 12) {
                TextField("Palette name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Toggle("Copy current live layers", isOn: $copyLiveLayers)
                    .font(.system(size: 11, design: .monospaced))
                HStack {
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Create") { createPalette(); isPresented = false }
                        .buttonStyle(.borderedProminent)
                        .tint(SmartLightTheme.purple)
                        .disabled(name.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(SmartLightTheme.surface)
    }

    private func createPalette() {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folderID }) else { return }
        let layers = copyLiveLayers ? appState.show.layers : []
        let palette = EffectPalette(name: name, layers: layers)
        appState.show.effectFolders[fi].palettes.append(palette)
    }
}

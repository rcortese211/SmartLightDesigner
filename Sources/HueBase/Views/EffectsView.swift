import SwiftUI

// Three-panel layout:  [Folders] | [Palettes] | [Layer Stack + Editor]
struct EffectsView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedFolderID: UUID?
    @State private var selectedPaletteID: UUID?
    @State private var selectedLayerID: UUID?
    @State private var showAddFolder = false
    @State private var showAddPalette = false

    var body: some View {
        HSplitView {
            folderColumn
                .frame(minWidth: 150, maxWidth: 200)
            paletteColumn
                .frame(minWidth: 170, maxWidth: 240)
            layerColumn
        }
        .navigationTitle("Effects")
        .toolbar {
            ToolbarItemGroup {
                Button(action: storeLiveAsNewPalette) {
                    Label("Store Live Stack", systemImage: "tray.and.arrow.down")
                }
                .disabled(selectedFolderID == nil)
                .help("Store the current live layer stack as a new palette in the selected folder")

                Button(action: recallSelectedPalette) {
                    Label("Recall Palette", systemImage: "bolt.fill")
                }
                .disabled(selectedPaletteID == nil)
                .help("Load this palette's layers into the live engine stack")
            }
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
            List(selection: $selectedFolderID) {
                ForEach(appState.show.effectFolders) { folder in
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(HueBaseTheme.purple.opacity(0.7))
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
            .background(HueBaseTheme.surface)

            Divider().background(HueBaseTheme.border)
            HStack {
                Button(action: { showAddFolder = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(HueBaseTheme.purple)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HueBaseTheme.surfaceHigh)
        }
        .background(HueBaseTheme.surface)
    }

    // MARK: - Palette Column

    private var paletteColumn: some View {
        VStack(spacing: 0) {
            PanelHeader(title: selectedFolder?.name ?? "Palettes")

            if let folder = selectedFolder {
                List(selection: $selectedPaletteID) {
                    ForEach(folder.palettes) { palette in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(palette.name)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
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
                            Button("Recall to Live Stack") { recallPalette(palette) }
                            Divider()
                            Button("Delete Palette", role: .destructive) { deletePalette(palette, from: folder) }
                        }
                        .onTapGesture(count: 2) { recallPalette(palette) }
                    }
                    .onMove { indices, dest in movePalette(in: folder, from: indices, to: dest) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(HueBaseTheme.surface)
            } else {
                VStack {
                    Spacer()
                    Text("Select a folder")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(HueBaseTheme.surface)
            }

            Divider().background(HueBaseTheme.border)
            HStack {
                Button(action: { showAddPalette = true }) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(HueBaseTheme.purple)
                .disabled(selectedFolderID == nil)

                Spacer()

                if selectedPaletteID != nil {
                    Button(action: recallSelectedPalette) {
                        Text("RECALL")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(HueBaseTheme.active)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(HueBaseTheme.surfaceHigh)
        }
        .background(HueBaseTheme.surface)
    }

    // MARK: - Layer Stack Column (palette content + editor)

    private var layerColumn: some View {
        HSplitView {
            paletteLayerStack
                .frame(minWidth: 200, maxWidth: 280)
            if let binding = selectedLayerBinding {
                LayerEditorView(layer: binding)
            } else {
                ContentUnavailableView("Select an Effect Layer", systemImage: "sparkles")
                    .background(HueBaseTheme.background)
            }
        }
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
                List(selection: $selectedLayerID) {
                    ForEach(palette.layers) { layer in
                        LayerRowView(layer: .constant(layer))
                            .tag(layer.id)
                    }
                    .onMove { if let (fi, pi) = findPalette() { movePaletteLayer(fi: fi, pi: pi, from: $0, to: $1) } }
                    .onDelete { if let (fi, pi) = findPalette() { deletePaletteLayer(fi: fi, pi: pi, at: $0) } }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(HueBaseTheme.surface)

                Divider().background(HueBaseTheme.border)
                HStack {
                    Button(action: addLayerToPalette) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HueBaseTheme.purple)

                    Spacer()

                    Button(action: recallSelectedPalette) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill").font(.system(size: 9))
                            Text("RECALL TO LIVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(HueBaseTheme.active)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(HueBaseTheme.surfaceHigh)
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
                .background(HueBaseTheme.surface)
            }
        }
        .background(HueBaseTheme.surface)
    }

    // MARK: - Computed helpers

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
            set: { appState.show.effectFolders[fi].palettes[pi].layers[li] = $0 }
        )
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
        selectedLayerID = layer.id
    }

    private func recallPalette(_ palette: EffectPalette) {
        appState.show.layers = palette.layers.map { src in
            Layer(id: UUID(), name: src.name, effectId: src.effectId,
                  isEnabled: src.isEnabled, opacity: src.opacity,
                  blendMode: src.blendMode, speed: src.speed,
                  parameters: src.parameters, fixtureIds: src.fixtureIds)
        }
        appState.statusMessage = "Recalled: \(palette.name)"
    }

    private func recallSelectedPalette() {
        guard let palette = selectedPalette else { return }
        recallPalette(palette)
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
                    .foregroundStyle(HueBaseTheme.purple.opacity(0.7))
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
                    .tint(HueBaseTheme.purple)
                    .disabled(name.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 300)
        .background(HueBaseTheme.surface)
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
                        .tint(HueBaseTheme.purple)
                        .disabled(name.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(HueBaseTheme.surface)
    }

    private func createPalette() {
        guard let fi = appState.show.effectFolders.firstIndex(where: { $0.id == folderID }) else { return }
        let layers = copyLiveLayers ? appState.show.layers : []
        let palette = EffectPalette(name: name, layers: layers)
        appState.show.effectFolders[fi].palettes.append(palette)
    }
}

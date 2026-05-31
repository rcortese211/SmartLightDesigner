import SwiftUI

struct EffectsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HSplitView {
            layerStack
                .frame(minWidth: 200, maxWidth: 260)
            if let layerId = appState.selectedLayerID,
               let idx = appState.show.layers.firstIndex(where: { $0.id == layerId }) {
                LayerEditorView(layer: layerBinding(idx))
            } else {
                ContentUnavailableView("Select a Layer", systemImage: "sparkles")
            }
        }
        .navigationTitle("Effects")
        .toolbar {
            ToolbarItemGroup {
                Button(action: addLayer) {
                    Label("Add Layer", systemImage: "plus")
                }
                Button(action: deleteSelectedLayer) {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(appState.selectedLayerID == nil)
            }
        }
    }

    private var layerStack: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Spacer()
            }
            Divider()
            List(selection: Binding(
                get: { appState.selectedLayerID },
                set: { appState.selectedLayerID = $0 }
            )) {
                ForEach(Array(appState.show.layers.enumerated()), id: \.element.id) { idx, layer in
                    LayerRowView(layer: layerBinding(idx))
                        .tag(layer.id)
                }
                .onMove { appState.show.layers.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { appState.show.layers.remove(atOffsets: $0) }
            }
            .listStyle(.plain)
        }
    }

    private func layerBinding(_ idx: Int) -> Binding<Layer> {
        Binding(
            get: { appState.show.layers[idx] },
            set: { appState.show.layers[idx] = $0 }
        )
    }

    private func addLayer() {
        let registry = EffectRegistry.shared
        let effectId = registry.allEffects.first?.id ?? "color_fill"
        let layer = Layer(
            name: "Layer \(appState.show.layers.count + 1)",
            effectId: effectId,
            parameters: registry.defaultParameters(for: effectId)
        )
        appState.show.layers.append(layer)
        appState.selectedLayerID = layer.id
    }

    private func deleteSelectedLayer() {
        guard let id = appState.selectedLayerID else { return }
        appState.show.layers.removeAll { $0.id == id }
        appState.selectedLayerID = nil
    }
}

struct LayerRowView: View {
    @Binding var layer: Layer

    var body: some View {
        HStack {
            Toggle("", isOn: $layer.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text(layer.name)
                .strikethrough(!layer.isEnabled)
                .foregroundStyle(layer.isEnabled ? .primary : .secondary)
            Spacer()
            Text(EffectRegistry.shared.effect(for: layer.effectId)?.name ?? layer.effectId)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

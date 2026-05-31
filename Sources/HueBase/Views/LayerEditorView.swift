import SwiftUI

struct LayerEditorView: View {
    @Binding var layer: Layer
    @Environment(AppState.self) private var appState

    private var effectDefs: [EffectParameterDefinition] {
        EffectRegistry.shared.effect(for: layer.effectId)?.parameterDefinitions ?? []
    }

    var body: some View {
        Form {
            Section("Layer") {
                TextField("Name", text: $layer.name)
                Picker("Effect", selection: $layer.effectId) {
                    ForEach(EffectRegistry.shared.allEffects, id: \.id) { e in
                        Text(e.name).tag(e.id)
                    }
                }
                .onChange(of: layer.effectId) { _, newId in
                    layer.parameters = EffectRegistry.shared.defaultParameters(for: newId)
                }
            }

            Section("Compositing") {
                LabeledContent("Opacity") {
                    HStack {
                        Slider(value: $layer.opacity, in: 0...1)
                        Text("\(Int(layer.opacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 38)
                    }
                }
                Picker("Blend Mode", selection: $layer.blendMode) {
                    ForEach(DMXBlendMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                LabeledContent("Speed") {
                    HStack {
                        Slider(value: $layer.speed, in: 0.05...8.0)
                        Text(String(format: "%.2f×", layer.speed))
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
                Toggle("Enabled", isOn: $layer.isEnabled)
            }

            Section("Parameters") {
                ForEach(effectDefs, id: \.key) { def in
                    parameterRow(for: def)
                }
            }

            Section("Fixture Scope") {
                if layer.fixtureIds.isEmpty {
                    Text("All fixtures").foregroundStyle(.secondary)
                } else {
                    Text("\(layer.fixtureIds.count) fixture(s) selected")
                        .foregroundStyle(.secondary)
                }
                Button("Assign Fixtures…") { assignFixtures() }
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func parameterRow(for def: EffectParameterDefinition) -> some View {
        let binding = paramBinding(for: def)
        switch def.type {
        case .double(let min, let max):
            LabeledContent(def.name) {
                HStack {
                    Slider(value: doubleBinding(binding, fallback: def.defaultValue.doubleValue ?? 0), in: min...max)
                    Text(String(format: "%.2f", binding.wrappedValue.doubleValue ?? 0))
                        .monospacedDigit()
                        .frame(width: 48)
                }
            }
        case .color:
            LabeledContent(def.name) {
                ColorPicker("", selection: colorSwiftUIBinding(binding))
                    .labelsHidden()
            }
        case .bool:
            Toggle(def.name, isOn: boolBinding(binding, fallback: def.defaultValue.boolValue ?? false))
        case .string:
            LabeledContent(def.name) {
                TextField("", text: stringBinding(binding))
                    .textFieldStyle(.roundedBorder)
            }
        case .select(let options):
            Picker(def.name, selection: stringBinding(binding)) {
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }
        }
    }

    private func paramBinding(for def: EffectParameterDefinition) -> Binding<ParameterValue> {
        Binding(
            get: { layer.parameters[def.key] ?? def.defaultValue },
            set: { layer.parameters[def.key] = $0 }
        )
    }

    private func doubleBinding(_ b: Binding<ParameterValue>, fallback: Double) -> Binding<Double> {
        Binding(
            get: { b.wrappedValue.doubleValue ?? fallback },
            set: { b.wrappedValue = .double($0) }
        )
    }

    private func boolBinding(_ b: Binding<ParameterValue>, fallback: Bool) -> Binding<Bool> {
        Binding(
            get: { b.wrappedValue.boolValue ?? fallback },
            set: { b.wrappedValue = .bool($0) }
        )
    }

    private func stringBinding(_ b: Binding<ParameterValue>) -> Binding<String> {
        Binding(
            get: { b.wrappedValue.stringValue ?? "" },
            set: { b.wrappedValue = .string($0) }
        )
    }

    private func colorSwiftUIBinding(_ b: Binding<ParameterValue>) -> Binding<Color> {
        Binding(
            get: {
                let (r, g, bv) = b.wrappedValue.colorValue ?? (1, 0, 0)
                return Color(red: r, green: g, blue: bv)
            },
            set: { color in
                let resolved = color.resolve(in: EnvironmentValues())
                b.wrappedValue = .color(r: Double(resolved.red),
                                        g: Double(resolved.green),
                                        b: Double(resolved.blue))
            }
        )
    }

    private func assignFixtures() {
        // Opens fixture selection — simple: toggle current show fixtures into layer.fixtureIds
        // A real implementation would show a picker sheet; wiring left for the full UI pass.
        layer.fixtureIds = []   // reset to "all" for now
    }
}

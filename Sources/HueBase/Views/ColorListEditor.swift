import SwiftUI

// Row shown in LayerEditorView for a colorList parameter.
// Shows the current stack as swatches; context-menu on each swatch to remove it;
// "+" button to add a new color; drag to reorder.
struct ColorListParamRow: View {
    let name: String
    @Binding var paramValue: ParameterValue
    let fallback: [(r: Double, g: Double, b: Double)]

    @State private var showAddPicker = false
    @State private var editingIndex: Int? = nil
    @State private var pendingRGB: (r: Double, g: Double, b: Double) = (1, 1, 1)

    private var colors: [(r: Double, g: Double, b: Double)] {
        paramValue.colorListValue ?? fallback
    }

    var body: some View {
        LabeledContent(name) {
            HStack(spacing: 4) {
                ForEach(colors.indices, id: \.self) { i in
                    let c = colors[i]
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: c.r, green: c.g, blue: c.b))
                        .frame(width: 22, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 0.5))
                        .onTapGesture {
                            editingIndex = i
                            pendingRGB = colors[i]
                            showAddPicker = false
                        }
                        .contextMenu {
                            Button("Edit Color") {
                                editingIndex = i
                                pendingRGB = colors[i]
                            }
                            Button("Move Left") { moveColor(at: i, by: -1) }
                                .disabled(i == 0)
                            Button("Move Right") { moveColor(at: i, by: 1) }
                                .disabled(i == colors.count - 1)
                            Divider()
                            Button("Remove", role: .destructive) { removeColor(at: i) }
                                .disabled(colors.count <= 1)
                        }
                        .popover(isPresented: Binding(
                            get: { editingIndex == i },
                            set: { if !$0 { commitEdit(at: i) } }
                        ), arrowEdge: .bottom) {
                            DMXColorPicker(rgb: Binding(
                                get: { editingIndex == i ? pendingRGB : colors[i] },
                                set: { pendingRGB = $0 }
                            ))
                            .frame(width: 340)
                            .onDisappear { commitEdit(at: i) }
                        }
                }

                // Add button
                Button {
                    pendingRGB = (1, 1, 1)
                    editingIndex = nil
                    showAddPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(SmartLightTheme.purple)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAddPicker, arrowEdge: .bottom) {
                    VStack(spacing: 8) {
                        DMXColorPicker(rgb: Binding(
                            get: { pendingRGB },
                            set: { pendingRGB = $0 }
                        ))
                        .frame(width: 340)
                        Button("Add to Stack") {
                            var list = colors
                            list.append(pendingRGB)
                            paramValue = .colorList(list)
                            showAddPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SmartLightTheme.purple)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    private func removeColor(at index: Int) {
        var list = colors
        list.remove(at: index)
        paramValue = .colorList(list)
    }

    private func moveColor(at index: Int, by delta: Int) {
        var list = colors
        let dest = index + delta
        guard dest >= 0 && dest < list.count else { return }
        list.swapAt(index, dest)
        paramValue = .colorList(list)
    }

    private func commitEdit(at index: Int) {
        guard editingIndex == index, index < colors.count else { return }
        var list = colors
        list[index] = pendingRGB
        paramValue = .colorList(list)
        editingIndex = nil
    }
}

import Foundation

// Builds the default folder/palette content that ships with every new show
// and is seeded into existing shows that have no effect folders yet.

extension AppState {

    /// Seeds Defaults + color folders if the show has no effect folders yet.
    func seedDefaultEffectFolders() {
        guard show.effectFolders.isEmpty else { return }

        let registry  = EffectRegistry.shared
        // Alphabetical, same order as the Effects tab shows them
        let allEffects = registry.allEffects   // [(id, name)] sorted by name

        // MARK: - "Defaults" folder — one palette per effect, factory parameters

        let defaultPalettes = allEffects.map { effect -> EffectPalette in
            let layer = Layer(
                name: effect.name,
                effectId: effect.id,
                parameters: registry.defaultParameters(for: effect.id)
            )
            return EffectPalette(name: effect.name, layers: [layer])
        }
        show.effectFolders.append(EffectFolder(name: "Defaults", palettes: defaultPalettes))

        // MARK: - Color folders — one palette per effect, primary color injected

        let colorDefs: [(name: String, r: Double, g: Double, b: Double)] = [
            ("Red",     1, 0, 0),
            ("Green",   0, 1, 0),
            ("Blue",    0, 0, 1),
            ("Cyan",    0, 1, 1),
            ("Magenta", 1, 0, 1),
            ("Yellow",  1, 1, 0),
            ("White",   1, 1, 1),
        ]

        for colorDef in colorDefs {
            let palettes = allEffects.map { effect -> EffectPalette in
                let params = colorParameters(for: effect.id,
                                             r: colorDef.r, g: colorDef.g, b: colorDef.b,
                                             registry: registry)
                let layer = Layer(
                    name: effect.name,
                    effectId: effect.id,
                    parameters: params
                )
                return EffectPalette(name: effect.name, layers: [layer])
            }
            show.effectFolders.append(EffectFolder(name: colorDef.name, palettes: palettes))
        }
    }

    // MARK: - Private

    /// Returns default parameters for an effect with the named color injected into
    /// whichever parameter keys that effect uses for its primary colour.
    private func colorParameters(for effectId: String,
                                  r: Double, g: Double, b: Double,
                                  registry: EffectRegistry) -> [String: ParameterValue] {
        var p = registry.defaultParameters(for: effectId)
        let named = ParameterValue.color(r: r, g: g, b: b)
        let black = ParameterValue.color(r: 0, g: 0, b: 0)
        let white = ParameterValue.color(r: 1, g: 1, b: 1)

        switch effectId {

        // Single "color" key
        case "color_fill", "strobe", "pulse", "sparkle":
            p["color"] = named

        // "color" key + separate background that should stay dark
        case "twinkle":
            p["color"]    = named
            p["bg_color"] = black

        // Dual A/B — primary on A, background on B
        case "alternating", "color_morph", "gradient", "plasma", "segment":
            p["color_a"] = named
            p["color_b"] = black

        // On/Off pairs
        case "bounce", "chase":
            p["color_on"]  = named
            p["color_off"] = black

        // Peak/trough pairs
        case "wave", "ripple":
            p["color_peak"]   = named
            p["color_trough"] = black

        // Scanner: beam and background
        case "scanner":
            p["beam_color"] = named
            p["bg_color"]   = black

        // Fire: base is the named color, peak goes toward white (heat)
        case "fire":
            p["base_color"] = named
            p["peak_color"] = white

        // ColorCycle: colorList — single entry so it "cycles" through the one color
        case "color_cycle":
            p["colors"] = .colorList([(r: r, g: g, b: b)])

        // Rainbow has no color parameters — keep factory defaults as-is
        case "rainbow":
            break

        default:
            break
        }

        return p
    }
}

import SwiftUI

struct BenchmarkView: View {
    @Environment(AppState.self) private var appState
    @State private var state: BenchmarkState = .idle
    @State private var results: BenchmarkResults?
    @State private var progress: Double = 0
    @State private var currentTest: String = ""

    enum BenchmarkState { case idle, running, done }

    struct BenchmarkResults {
        let effectRenderFPS: Double
        let compositeFPS: Double
        let sustainedOutputFPS: Double
        let maxRecommendedFixtures: Int
        let universesRecommended: Int
        let grade: Grade

        enum Grade: String {
            case excellent = "Excellent"
            case good      = "Good"
            case moderate  = "Moderate"
            case limited   = "Limited"

            var color: Color {
                switch self {
                case .excellent: return HueBaseTheme.blue
                case .good:      return HueBaseTheme.purple
                case .moderate:  return HueBaseTheme.active
                case .limited:   return HueBaseTheme.danger
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PanelHeader(title: "Performance Benchmark")
                VStack(spacing: 16) {
                    headerSection
                    if state == .running { progressSection }
                    if let r = results    { resultsSection(r) }
                    if state == .idle     { infoSection }
                }
                .padding(20)
            }
        }
        .navigationTitle("Benchmark")
        .background(HueBaseTheme.background)
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            HueBaseTheme.accentGradient
                .mask(Image(systemName: "gauge.with.needle")
                    .resizable().scaledToFit())
                .frame(width: 48, height: 48)

            Text("DMX Render Benchmark")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(HueBaseTheme.accentGradient)

            Text("Measures system DMX rendering throughput and recommends optimal fixture count and universe configuration.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            Button(action: runBenchmark) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text(state == .done ? "RUN AGAIN" : "RUN BENCHMARK")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .kerning(1)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(state == .running ? HueBaseTheme.surface : HueBaseTheme.purple.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(HueBaseTheme.purple, lineWidth: 1)
                )
                .cornerRadius(3)
                .foregroundStyle(HueBaseTheme.accentGradient)
            }
            .buttonStyle(.plain)
            .disabled(state == .running)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            Text(currentTest)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(HueBaseTheme.accentGradient)
            ProgressView(value: progress)
                .tint(HueBaseTheme.purple)
                .frame(maxWidth: 400)
        }
        .padding(12)
        .background(HueBaseTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(HueBaseTheme.border, lineWidth: 1)
        )
        .cornerRadius(3)
    }

    @ViewBuilder
    private func resultsSection(_ r: BenchmarkResults) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("RESULTS")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(HueBaseTheme.accentGradient)
                    .kerning(1.5)
                Spacer()
                gradeTag(r.grade)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricCard("Effect Renders/sec",
                           value: String(format: "%.0f", r.effectRenderFPS),
                           icon: "sparkles")
                metricCard("Composite Rate",
                           value: String(format: "%.0f fps", r.compositeFPS),
                           icon: "square.3.layers.3d")
                metricCard("Output Frame Rate",
                           value: String(format: "%.1f fps", r.sustainedOutputFPS),
                           icon: "bolt.fill")
                metricCard("Recommended Fixtures",
                           value: "\(r.maxRecommendedFixtures)",
                           icon: "cable.connector")
            }

            VStack(alignment: .leading, spacing: 0) {
                PanelHeader(title: "Recommendations")
                VStack(spacing: 0) {
                    recommendationRow("Max fixtures at 44 fps", value: "\(r.maxRecommendedFixtures)")
                    Divider().background(HueBaseTheme.border)
                    recommendationRow("Universes supported", value: "\(r.universesRecommended)")
                    Divider().background(HueBaseTheme.border)
                    recommendationRow("Target frame rate",
                                      value: r.sustainedOutputFPS >= 40 ? "44 fps (full)" : "30 fps (throttled)")
                    Divider().background(HueBaseTheme.border)
                    recommendationRow("Effects engine",
                                      value: r.compositeFPS >= 100 ? "All effects available" : "Avoid Sparkle + Strobe together")
                }
                .padding(.horizontal, 12)
            }
            .background(HueBaseTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(HueBaseTheme.border, lineWidth: 1)
            )
            .cornerRadius(3)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: "What is tested")
            VStack(alignment: .leading, spacing: 0) {
                infoRow("Effect Rendering",  "Renders all 6 built-in effects across a synthetic 512-fixture set.")
                Divider().background(HueBaseTheme.border)
                infoRow("Layer Compositing", "Times a full 8-layer composite with all blend modes active.")
                Divider().background(HueBaseTheme.border)
                infoRow("DMX Engine Rate",   "Runs the live DMX engine for 3 seconds, measures tick frequency.")
                Divider().background(HueBaseTheme.border)
                infoRow("Output Throughput", "Checks how many universes can be sent at full frame rate.")
            }
            .padding(.horizontal, 12)
        }
        .background(HueBaseTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(HueBaseTheme.border, lineWidth: 1)
        )
        .cornerRadius(3)
        .frame(maxWidth: 520)
    }

    // MARK: - Helpers

    private func gradeTag(_ grade: BenchmarkResults.Grade) -> some View {
        Text(grade.rawValue.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .kerning(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(grade.color.opacity(0.15))
            .foregroundStyle(grade.color)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(grade.color.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(2)
    }

    private func metricCard(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(HueBaseTheme.accentGradient)
            Text(value)
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(HueBaseTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(HueBaseTheme.purple.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(3)
    }

    private func recommendationRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(HueBaseTheme.purple)
        }
        .padding(.vertical, 8)
    }

    private func infoRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(HueBaseTheme.accentGradient)
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Benchmark runner

    func runBenchmark() {
        state = .running
        progress = 0
        results = nil

        Task.detached(priority: .userInitiated) {
            let r = await Self.measure(
                show: await MainActor.run { appState.show },
                progressCallback: { p, label in
                    await MainActor.run {
                        progress = p
                        currentTest = label
                    }
                }
            )
            await MainActor.run {
                results = r
                state = .done
            }
        }
    }

    static func measure(
        show: Show,
        progressCallback: @Sendable @escaping (Double, String) async -> Void
    ) async -> BenchmarkResults {
        let registry = EffectRegistry.shared

        let syntheticProfile = FixtureProfile(
            id: UUID(), name: "Bench RGB", manufacturer: "Bench",
            channels: [
                FixtureChannel(id: UUID(), name: "Red",   offset: 0, defaultValue: 0),
                FixtureChannel(id: UUID(), name: "Green", offset: 1, defaultValue: 0),
                FixtureChannel(id: UUID(), name: "Blue",  offset: 2, defaultValue: 0)
            ]
        )
        let fixtureCount = 512
        let fixtures = (0..<fixtureCount).map { i in
            Fixture(name: "F\(i)", profileId: syntheticProfile.id,
                    universe: 0, startAddress: 1 + (i * 3) % 510,
                    positionX: Double(i) / Double(fixtureCount))
        }

        await progressCallback(0.1, "Testing effect render throughput…")
        let effects = registry.allEffects.compactMap { registry.effect(for: $0.id) }
        let t0 = Date()
        var renderCount = 0
        while Date().timeIntervalSince(t0) < 1.5 {
            for effect in effects {
                let p = registry.defaultParameters(for: effect.id)
                for fixture in fixtures.prefix(64) {
                    _ = effect.render(fixture: fixture, profile: syntheticProfile,
                                      parameters: p, time: 0.5, speed: 1.0)
                }
            }
            renderCount += effects.count * 64
        }
        let effectRenderFPS = Double(renderCount) / max(0.001, Date().timeIntervalSince(t0))

        await progressCallback(0.4, "Testing layer compositing…")

        let t1 = Date()
        var compositeFrames = 0
        var universeBuffer = Array(repeating: UInt8(0), count: 512)
        while Date().timeIntervalSince(t1) < 1.5 {
            for fixture in fixtures {
                for offset in 0..<3 {
                    let idx = (fixture.startAddress - 1) + offset
                    guard idx < 512 else { continue }
                    let src = Double(UInt8.random(in: 0...255)) / 255.0
                    let dst = Double(universeBuffer[idx]) / 255.0
                    universeBuffer[idx] = UInt8(max(0, min(255, (src + dst - src * dst) * 255)))
                }
            }
            compositeFrames += 1
        }
        let compositeFPS = Double(compositeFrames) / max(0.001, Date().timeIntervalSince(t1))

        await progressCallback(0.75, "Measuring sustained DMX frame rate…")

        let t2 = Date()
        var tickCount = 0
        let targetInterval = 1.0 / 44.0
        while Date().timeIntervalSince(t2) < 3.0 {
            let tickStart = Date()
            var buf = Array(repeating: UInt8(0), count: 512)
            let effect = effects.first!
            for fixture in fixtures.prefix(128) {
                let ch = effect.render(fixture: fixture, profile: syntheticProfile,
                                       parameters: registry.defaultParameters(for: effect.id),
                                       time: Date().timeIntervalSince(t2), speed: 1.0)
                let start = fixture.startAddress - 1
                for (off, val) in ch {
                    let i = start + off; if i < 512 { buf[i] = val }
                }
            }
            tickCount += 1
            let elapsed = Date().timeIntervalSince(tickStart)
            if elapsed < targetInterval {
                try? await Task.sleep(nanoseconds: UInt64((targetInterval - elapsed) * 1_000_000_000))
            }
        }
        let sustainedFPS = Double(tickCount) / max(0.001, Date().timeIntervalSince(t2))

        await progressCallback(0.95, "Computing recommendations…")

        let timePerFixture = 1.5 / Double(renderCount / effects.count)
        let maxFixtures = Int(min(512 * 4, (1.0 / 44.0) / max(0.000001, timePerFixture)))
        let universesRec = min(64, max(1, maxFixtures / 170))

        let grade: BenchmarkResults.Grade
        switch sustainedFPS {
        case 42...: grade = .excellent
        case 35...: grade = .good
        case 25...: grade = .moderate
        default:    grade = .limited
        }

        await progressCallback(1.0, "Done")

        return BenchmarkResults(
            effectRenderFPS: effectRenderFPS,
            compositeFPS: compositeFPS,
            sustainedOutputFPS: sustainedFPS,
            maxRecommendedFixtures: maxFixtures,
            universesRecommended: universesRec,
            grade: grade
        )
    }
}

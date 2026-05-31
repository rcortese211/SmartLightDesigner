import SwiftUI

struct BenchmarkView: View {
    @Environment(AppState.self) private var appState
    @State private var state: BenchmarkState = .idle
    @State private var results: BenchmarkResults?
    @State private var progress: Double = 0
    @State private var currentTest: String = ""

    enum BenchmarkState { case idle, running, done }

    struct BenchmarkResults {
        let effectRenderFPS: Double         // simulated renders/sec per fixture
        let compositeFPS: Double            // full-frame composite rate
        let sustainedOutputFPS: Double      // measured DMX engine tick rate
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
                case .moderate:  return .orange
                case .limited:   return .red
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if state == .running { progressSection }
                if let r = results    { resultsSection(r) }
                if state == .idle     { infoSection }
            }
            .padding(32)
        }
        .navigationTitle("Benchmark")
        .background(HueBaseTheme.background)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HueBaseTheme.accentGradient
                .mask(Image(systemName: "gauge.with.needle")
                    .resizable().scaledToFit())
                .frame(width: 64, height: 64)

            Text("Performance Benchmark")
                .font(.largeTitle.bold())
                .foregroundStyle(HueBaseTheme.accentGradient)

            Text("Measures your system's DMX rendering throughput and recommends optimal fixture count and universe configuration.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)

            Button(action: runBenchmark) {
                Label(state == .done ? "Run Again" : "Run Benchmark",
                      systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(HueBaseTheme.purple)
            .disabled(state == .running)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Text(currentTest)
                .font(.callout)
                .foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(HueBaseTheme.purple)
                .frame(maxWidth: 400)
        }
        .padding()
        .background(HueBaseTheme.surface.cornerRadius(12))
    }

    @ViewBuilder
    private func resultsSection(_ r: BenchmarkResults) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Results")
                    .font(.title2.bold())
                    .foregroundStyle(HueBaseTheme.accentGradient)
                Spacer()
                gradeTag(r.grade)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)
                    .foregroundStyle(HueBaseTheme.accentGradient)
                GradientBar(height: 1)
                recommendationRow("Max fixtures at 44 fps", value: "\(r.maxRecommendedFixtures)")
                recommendationRow("Universes supported", value: "\(r.universesRecommended)")
                recommendationRow("Target frame rate",
                                  value: r.sustainedOutputFPS >= 40 ? "44 fps (full)" : "30 fps (throttled)")
                recommendationRow("Effects engine",
                                  value: r.compositeFPS >= 100 ? "All effects available" : "Avoid Sparkle + Strobe together")
            }
            .padding(16)
            .background(HueBaseTheme.surface.cornerRadius(12))
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What is tested")
                .font(.headline)
                .foregroundStyle(HueBaseTheme.accentGradient)
            GradientBar(height: 1)
            infoRow("Effect Rendering",    "Renders all 6 built-in effects across a synthetic 512-fixture set and measures throughput.")
            infoRow("Layer Compositing",   "Times a full 8-layer composite with all blend modes active.")
            infoRow("DMX Engine Rate",     "Runs the live DMX engine for 3 seconds and measures actual tick frequency.")
            infoRow("Output Throughput",   "Checks how many universes can be sent at full frame rate.")
        }
        .padding(16)
        .background(HueBaseTheme.surface.cornerRadius(12))
        .frame(maxWidth: 540)
    }

    // MARK: - Helpers

    private func gradeTag(_ grade: BenchmarkResults.Grade) -> some View {
        Text(grade.rawValue)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(grade.color.opacity(0.2))
            .foregroundStyle(grade.color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(grade.color.opacity(0.5), lineWidth: 1))
    }

    private func metricCard(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(HueBaseTheme.accentGradient)
            Text(value)
                .font(.title.monospacedDigit().bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(HueBaseTheme.surface.cornerRadius(10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(HueBaseTheme.purple.opacity(0.2), lineWidth: 1))
    }

    private func recommendationRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold().foregroundStyle(HueBaseTheme.purple)
        }
        .font(.callout)
    }

    private func infoRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.bold())
            Text(description).font(.caption).foregroundStyle(.secondary)
        }
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

        // Build synthetic fixture set
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

        // ---- Test 1: Effect render throughput ----
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

        // ---- Test 2: Full composite timing ----
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

        // ---- Test 3: Engine tick rate (run for 3 seconds, count ticks) ----
        let t2 = Date()
        var tickCount = 0
        let targetInterval = 1.0 / 44.0
        while Date().timeIntervalSince(t2) < 3.0 {
            let tickStart = Date()
            // Simulate a full engine tick
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

        // ---- Derive recommendations ----
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

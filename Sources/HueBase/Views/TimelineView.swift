import SwiftUI
import AppKit

// ──────────────────────────────────────────────────────────────────────────────
// TimelineView — multi-track DAW-style sequencer.
//
// Layout:
//   Transport bar (top, fixed)
//   HStack:
//     Track header column (fixed 144pt, scrolls vertically with tracks)
//     ScrollView(.horizontal):
//       Ruler + track rows (VStack) + playhead overlay
// ──────────────────────────────────────────────────────────────────────────────

private let kTrackHeight:   CGFloat = 60
private let kRulerHeight:   CGFloat = 28
private let kHeaderWidth:   CGFloat = 144
private let kEdgeZone:      CGFloat = 8
private let kMinDuration:   Double  = 0.25

struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var pixelsPerSecond: Double = 80.0

    // Clip interaction state
    @State private var selectedClipID: UUID? = nil
    @State private var dragState: ClipDragState? = nil

    // Inline rename
    @State private var renamingClipID: UUID? = nil
    @State private var renameText: String = ""

    // Playhead scrub
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 0) {
            transportBar
            Divider().background(HueBaseTheme.border)

            HStack(alignment: .top, spacing: 0) {
                trackHeaderColumn
                Divider().background(HueBaseTheme.border)
                timelineScrollArea
            }
            .frame(maxHeight: .infinity)
        }
        .background(HueBaseTheme.background)
        .background {
            Button("") {
                if appState.timelineEngine.isPlaying { appState.timelineEngine.pause() }
                else { appState.timelineEngine.play() }
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)
            .allowsHitTesting(false)
        }
        .onDisappear {
            if appState.timelineEngine.isPlaying { appState.timelineEngine.pause() }
        }
    }

    // MARK: - Transport bar

    private var transportBar: some View {
        @Bindable var state = appState
        return HStack(spacing: 8) {
            // Rewind
            transportBtn(icon: "backward.end.fill") { appState.timelineEngine.stop() }

            // Play / Pause
            transportBtn(
                icon: appState.timelineEngine.isPlaying ? "pause.fill" : "play.fill",
                tint: HueBaseTheme.active
            ) {
                if appState.timelineEngine.isPlaying { appState.timelineEngine.pause() }
                else { appState.timelineEngine.play() }
            }

            // Stop
            transportBtn(icon: "stop.fill") { appState.timelineEngine.stop() }

            // Loop
            let looping = appState.show.timeline.loop
            Button {
                appState.show.timeline.loop.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 11))
                    .frame(width: 22, height: 20)
                    .foregroundStyle(looping ? HueBaseTheme.active : Color(white: 0.4))
                    .background(looping ? HueBaseTheme.active.opacity(0.18) : HueBaseTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(HueBaseTheme.border, lineWidth: 1))
                    .cornerRadius(2)
            }
            .buttonStyle(.plain)

            HueBaseTheme.border.frame(width: 1).padding(.vertical, 4)

            // Time display
            Text(formatTime(appState.timelineEngine.playheadTime))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(appState.timelineEngine.isPlaying ? HueBaseTheme.active : Color(white: 0.65))
                .frame(width: 88, alignment: .leading)

            Spacer()

            // BPM
            HStack(spacing: 4) {
                Text("BPM")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                TextField("", value: $state.show.timeline.bpm, formatter: bpmFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 52)
                    .font(.system(size: 11, design: .monospaced))
            }

            HueBaseTheme.border.frame(width: 1).padding(.vertical, 4)

            // Zoom
            HStack(spacing: 4) {
                Text("ZOOM")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.35))
                Slider(value: $pixelsPerSecond, in: 20...400)
                    .frame(width: 100)
                    .tint(HueBaseTheme.purple)
            }

            HueBaseTheme.border.frame(width: 1).padding(.vertical, 4)

            // Add track
            Button {
                let n = appState.show.timeline.tracks.count + 1
                appState.show.timeline.tracks.append(
                    TimelineTrack(name: "Track \(n)")
                )
            } label: {
                Label("Add Track", systemImage: "plus.rectangle.on.rectangle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(height: 36)
        .background(HueBaseTheme.surfaceHigh)
    }

    // MARK: - Track header column

    private var trackHeaderColumn: some View {
        VStack(spacing: 0) {
            // Ruler spacer
            Color.clear.frame(height: kRulerHeight)
            Divider().background(HueBaseTheme.border)

            ForEach(Array(appState.show.timeline.tracks.enumerated()), id: \.element.id) { idx, track in
                trackHeader(track: track, index: idx)
                Divider().background(HueBaseTheme.border)
            }

            // Audio track header
            audioTrackHeader

            Spacer()
        }
        .frame(width: kHeaderWidth)
        .background(HueBaseTheme.surfaceHigh)
    }

    private func trackHeader(track: TimelineTrack, index: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                // Name (truncated)
                Text(track.name)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.78))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Add clip at playhead
                Button {
                    addClipAt(x: CGFloat(appState.timelineEngine.playheadTime * pixelsPerSecond),
                              trackIndex: index)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                        .foregroundStyle(HueBaseTheme.purple)
                }
                .buttonStyle(.plain)
                .help("Add clip at playhead from current layer stack")

                // Mute
                Button {
                    appState.show.timeline.tracks[index].isMuted.toggle()
                } label: {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(track.isMuted ? Color.orange : Color(white: 0.4))
                }
                .buttonStyle(.plain)
                .help(track.isMuted ? "Unmute" : "Mute")

                // Delete
                Button {
                    appState.show.timeline.tracks.remove(at: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(white: 0.3))
                }
                .buttonStyle(.plain)
            }

        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: kTrackHeight)
        .opacity(track.isMuted ? 0.5 : 1)
    }

    private var audioTrackHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.45))
            VStack(alignment: .leading, spacing: 2) {
                Text("AUDIO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.55))
                if appState.audioPlayer.isLoaded {
                    Text(appState.audioPlayer.fileName)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(Color(white: 0.35))
                        .lineLimit(1)
                }
            }
            Spacer()

            Button {
                importAudioFile()
            } label: {
                Image(systemName: appState.audioPlayer.isLoaded ? "arrow.triangle.2.circlepath" : "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(HueBaseTheme.purple)
            }
            .buttonStyle(.plain)
            .help(appState.audioPlayer.isLoaded ? "Replace audio file" : "Import audio file")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(height: kTrackHeight)
    }

    // MARK: - Timeline scroll area

    private var timelineScrollArea: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    timeRuler
                    Divider().background(HueBaseTheme.border)

                    ForEach(Array(appState.show.timeline.tracks.enumerated()), id: \.element.id) { idx, track in
                        trackRow(track: track, index: idx)
                        Divider().background(HueBaseTheme.border)
                    }

                    audioRow
                    Spacer()
                }
                .frame(width: totalWidth)

                // Playhead
                playheadOverlay
            }
            .frame(minWidth: totalWidth)
        }
        .background(HueBaseTheme.background)
    }

    // MARK: - Ruler

    private var timeRuler: some View {
        Canvas { ctx, size in
            let step = pixelsPerSecond
            // Determine label interval based on zoom
            let labelInterval: Double
            if step >= 120 { labelInterval = 1 }
            else if step >= 40 { labelInterval = 2 }
            else if step >= 20 { labelInterval = 5 }
            else { labelInterval = 10 }

            var t: Double = 0
            while t * step < size.width {
                let x = t * step
                let isLabel = t.truncatingRemainder(dividingBy: labelInterval) < 0.001
                let isMajor = t.truncatingRemainder(dividingBy: 60) < 0.001
                let lineH: CGFloat = isMajor ? 20 : (isLabel ? 14 : 6)
                ctx.stroke(
                    Path { p in
                        p.move(to: CGPoint(x: x, y: kRulerHeight - lineH))
                        p.addLine(to: CGPoint(x: x, y: kRulerHeight))
                    },
                    with: .color(isMajor ? HueBaseTheme.purple.opacity(0.6) : HueBaseTheme.border),
                    lineWidth: isMajor ? 1 : 0.5
                )
                if isLabel {
                    ctx.draw(
                        Text(formatTime(t))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Color(white: 0.42)),
                        at: CGPoint(x: x + 3, y: 4)
                    )
                }
                t += 1
            }
        }
        .frame(height: kRulerHeight)
        .background(HueBaseTheme.surfaceHigh)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let t = max(0, v.location.x / pixelsPerSecond)
                    appState.timelineEngine.seek(to: t)
                }
        )
    }

    // MARK: - Track rows

    private func trackRow(track: TimelineTrack, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            // Background + grid lines
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(white: index.isMultiple(of: 2) ? 0.065 : 0.07)))
                // Beat grid at current BPM
                let bps = appState.show.timeline.bpm / 60.0
                let beatPx = pixelsPerSecond / bps
                if beatPx > 8 {
                    var x: CGFloat = 0
                    var beat = 0
                    while x < size.width {
                        let isBar = beat.isMultiple(of: 4)
                        ctx.stroke(
                            Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) },
                            with: .color(isBar ? Color(white: 0.18) : Color(white: 0.12)),
                            lineWidth: 0.5
                        )
                        x += beatPx
                        beat += 1
                    }
                }
            }

            // Clips
            let sortedClips = track.clips.sorted { $0.startTime < $1.startTime }
            ForEach(sortedClips) { clip in
                clipView(clip: clip, trackIndex: index)
                    .frame(width: max(kEdgeZone * 2, clip.duration * pixelsPerSecond),
                           height: kTrackHeight - 4)
                    .offset(x: clip.startTime * pixelsPerSecond, y: 2)
            }

            // Crossfade overlays
            crossfadeOverlays(sortedClips: sortedClips)
        }
        .frame(width: totalWidth, height: kTrackHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture(count: 2)
                .onEnded { value in
                    let t = Double(value.location.x) / pixelsPerSecond
                    let overClip = track.clips.contains { t >= $0.startTime && t < $0.endTime }
                    if !overClip { addClipAt(x: value.location.x, trackIndex: index) }
                }
        )
        .dropDestination(for: PaletteTransfer.self) { items, location in
            guard let item = items.first else { return false }
            let t = Double(location.x) / pixelsPerSecond
            let hue = Double.random(in: 0...1)
            let clip = TimelineClip(startTime: max(0, t), layers: item.layers,
                                    label: item.paletteName, colorHue: hue)
            appState.show.timeline.tracks[index].clips.append(clip)
            normalizeCrossfades(trackIndex: index)
            return true
        }
    }

    // MARK: - Clip view

    private func clipView(clip: TimelineClip, trackIndex: Int) -> some View {
        let color = Color(hue: clip.colorHue, saturation: 0.62, brightness: 0.58)
        let isSelected = selectedClipID == clip.id

        return ZStack(alignment: .leading) {
            // Body
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.32))
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(isSelected ? Color.white.opacity(0.85) : color.opacity(0.8),
                              lineWidth: isSelected ? 1.5 : 1)

            // Top colour bar
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(height: 3)
                Spacer()
            }

            // Label
            if let renamingID = renamingClipID, renamingID == clip.id {
                TextField("", text: $renameText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.white)
                    .padding(.leading, 6)
                    .padding(.top, 6)
                    .onSubmit { commitRename(clipID: clip.id, trackIndex: trackIndex) }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.label)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                    Text("\(clip.layers.count) layer\(clip.layers.count == 1 ? "" : "s")")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                }
                .padding(.leading, 6)
                .padding(.top, 4)
            }

            // Left resize handle
            HStack {
                Color.white.opacity(0.0)
                    .frame(width: kEdgeZone)
                    .contentShape(Rectangle())
                    .gesture(resizeDragGesture(clip: clip, trackIndex: trackIndex, edge: .left))
                Spacer()
            }

            // Right resize handle
            HStack {
                Spacer()
                Color.white.opacity(0.0)
                    .frame(width: kEdgeZone)
                    .contentShape(Rectangle())
                    .gesture(resizeDragGesture(clip: clip, trackIndex: trackIndex, edge: .right))
            }
        }
        .onTapGesture { selectedClipID = (selectedClipID == clip.id ? nil : clip.id) }
        .gesture(clipMoveDragGesture(clip: clip, trackIndex: trackIndex))
        .contextMenu {
            Button("Rename…") {
                renamingClipID = clip.id
                renameText = clip.label
            }
            Divider()
            Button("Duplicate") { duplicateClip(clip, trackIndex: trackIndex) }
            Button("Delete", role: .destructive) { deleteClip(id: clip.id, trackIndex: trackIndex) }
        }
    }

    // MARK: - Crossfade overlays

    @ViewBuilder
    private func crossfadeOverlays(sortedClips: [TimelineClip]) -> some View {
        ForEach(0..<max(0, sortedClips.count - 1), id: \.self) { i in
            let a = sortedClips[i]
            let b = sortedClips[i + 1]
            if b.startTime < a.endTime {
                let xfadeStart = b.startTime * pixelsPerSecond
                let xfadeW = max(4, (a.endTime - b.startTime) * pixelsPerSecond)
                let colorA = Color(hue: a.colorHue, saturation: 0.62, brightness: 0.58)
                let colorB = Color(hue: b.colorHue, saturation: 0.62, brightness: 0.58)

                Canvas { ctx, size in
                    // Triangle A (top-left) — clip A fades out
                    var pathA = Path()
                    pathA.move(to: .zero)
                    pathA.addLine(to: CGPoint(x: size.width, y: 0))
                    pathA.addLine(to: CGPoint(x: 0, y: size.height))
                    pathA.closeSubpath()
                    ctx.fill(pathA, with: .color(colorA.opacity(0.35)))

                    // Triangle B (bottom-right) — clip B fades in
                    var pathB = Path()
                    pathB.move(to: CGPoint(x: size.width, y: 0))
                    pathB.addLine(to: CGPoint(x: size.width, y: size.height))
                    pathB.addLine(to: CGPoint(x: 0, y: size.height))
                    pathB.closeSubpath()
                    ctx.fill(pathB, with: .color(colorB.opacity(0.35)))

                    // Diagonal divider line
                    ctx.stroke(
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: size.width, y: size.height))
                        },
                        with: .color(Color.white.opacity(0.6)), lineWidth: 1
                    )

                    // "X" crossfade symbol in centre
                    let cx = size.width / 2
                    let cy = size.height / 2
                    let r: CGFloat = 5
                    ctx.stroke(Path { p in
                        p.move(to: CGPoint(x: cx - r, y: cy - r))
                        p.addLine(to: CGPoint(x: cx + r, y: cy + r))
                        p.move(to: CGPoint(x: cx + r, y: cy - r))
                        p.addLine(to: CGPoint(x: cx - r, y: cy + r))
                    }, with: .color(Color.white.opacity(0.7)), lineWidth: 1.5)
                }
                .frame(width: xfadeW, height: kTrackHeight - 4)
                .offset(x: xfadeStart, y: 2)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Audio row

    private var audioRow: some View {
        ZStack(alignment: .topLeading) {
            Color(white: 0.055)

            if let ac = appState.show.timeline.audioClip {
                let clipW = max(4, (appState.audioPlayer.isLoaded
                    ? appState.audioPlayer.fileDuration
                    : ac.fileDuration) * pixelsPerSecond)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hue: 0.55, saturation: 0.5, brightness: 0.35))
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(hue: 0.55, saturation: 0.6, brightness: 0.55), lineWidth: 1)

                    // Waveform placeholder
                    Canvas { ctx, size in
                        let midY = size.height / 2
                        let amplitude: CGFloat = size.height * 0.35
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: midY))
                        let steps = Int(size.width / 3)
                        for i in 0...steps {
                            let x = CGFloat(i) * 3
                            let y = midY + sin(Double(i) * 0.42) * Double(amplitude) *
                                (0.5 + 0.5 * sin(Double(i) * 0.13))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        ctx.stroke(path, with: .color(Color(hue: 0.55, saturation: 0.4, brightness: 0.7).opacity(0.6)), lineWidth: 1)
                    }

                    Text(ac.fileName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.leading, 6)
                        .lineLimit(1)
                }
                .frame(width: clipW, height: kTrackHeight - 4)
                .offset(x: ac.startTime * pixelsPerSecond, y: 2)
            } else {
                Text("Drop audio file or use Import in the track header")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color(white: 0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: totalWidth, height: kTrackHeight)
        .clipped()
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            _ = providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async { importAudioURL(url) }
                } else if let url = item as? URL {
                    DispatchQueue.main.async { importAudioURL(url) }
                }
            }
            return true
        }
    }

    // MARK: - Playhead

    private var playheadOverlay: some View {
        let x = appState.timelineEngine.playheadTime * pixelsPerSecond
        return ZStack(alignment: .topLeading) {
            // Line
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 1)
                .offset(x: x)

            // Triangle head on ruler
            Path { p in
                p.move(to: CGPoint(x: x - 5, y: 0))
                p.addLine(to: CGPoint(x: x + 5, y: 0))
                p.addLine(to: CGPoint(x: x, y: 10))
                p.closeSubpath()
            }
            .fill(Color.white)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gestures

    private func clipMoveDragGesture(clip: TimelineClip, trackIndex: Int) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in
                if dragState == nil {
                    dragState = ClipDragState(
                        clipID: clip.id, trackIndex: trackIndex, mode: .move,
                        anchorStart: clip.startTime, anchorDuration: clip.duration,
                        grabOffsetX: Double(v.startLocation.x) / pixelsPerSecond
                    )
                }
                guard var ds = dragState, ds.clipID == clip.id, ds.mode == .move else { return }
                let newStart = max(0, ds.anchorStart + Double(v.translation.width) / pixelsPerSecond)
                updateClip(id: clip.id, trackIndex: trackIndex) { $0.startTime = newStart }
            }
            .onEnded { _ in
                normalizeCrossfades(trackIndex: trackIndex)
                dragState = nil
            }
    }

    private enum ResizeEdge { case left, right }

    private func resizeDragGesture(clip: TimelineClip, trackIndex: Int, edge: ResizeEdge) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                if dragState == nil {
                    dragState = ClipDragState(
                        clipID: clip.id, trackIndex: trackIndex,
                        mode: edge == .left ? .resizeLeft : .resizeRight,
                        anchorStart: clip.startTime, anchorDuration: clip.duration,
                        grabOffsetX: 0
                    )
                }
                guard let ds = dragState, ds.clipID == clip.id else { return }
                let delta = Double(v.translation.width) / pixelsPerSecond
                if edge == .left {
                    let newStart = max(0, ds.anchorStart + delta)
                    let newDur = max(kMinDuration, ds.anchorDuration - (newStart - ds.anchorStart))
                    updateClip(id: clip.id, trackIndex: trackIndex) {
                        $0.startTime = newStart
                        $0.duration = newDur
                    }
                } else {
                    let newDur = max(kMinDuration, ds.anchorDuration + delta)
                    updateClip(id: clip.id, trackIndex: trackIndex) { $0.duration = newDur }
                }
            }
            .onEnded { _ in
                normalizeCrossfades(trackIndex: trackIndex)
                dragState = nil
            }
    }

    // MARK: - Data mutations

    private func updateClip(id: UUID, trackIndex: Int, mutation: (inout TimelineClip) -> Void) {
        guard trackIndex < appState.show.timeline.tracks.count,
              let ci = appState.show.timeline.tracks[trackIndex].clips.firstIndex(where: { $0.id == id })
        else { return }
        mutation(&appState.show.timeline.tracks[trackIndex].clips[ci])
    }

    private func deleteClip(id: UUID, trackIndex: Int) {
        guard trackIndex < appState.show.timeline.tracks.count else { return }
        appState.show.timeline.tracks[trackIndex].clips.removeAll { $0.id == id }
        normalizeCrossfades(trackIndex: trackIndex)
        if selectedClipID == id { selectedClipID = nil }
    }

    private func duplicateClip(_ clip: TimelineClip, trackIndex: Int) {
        var copy = clip
        copy.id = UUID()
        copy.startTime = clip.endTime + 0.5
        appState.show.timeline.tracks[trackIndex].clips.append(copy)
        normalizeCrossfades(trackIndex: trackIndex)
    }

    private func commitRename(clipID: UUID, trackIndex: Int) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            updateClip(id: clipID, trackIndex: trackIndex) { $0.label = name }
        }
        renamingClipID = nil
    }

    private func normalizeCrossfades(trackIndex: Int) {
        guard trackIndex < appState.show.timeline.tracks.count else { return }
        var track = appState.show.timeline.tracks[trackIndex]
        track.clips.sort { $0.startTime < $1.startTime }
        for i in 0..<track.clips.count {
            track.clips[i].fadeInDuration = 0
            track.clips[i].fadeOutDuration = 0
        }
        for i in 0..<max(0, track.clips.count - 1) {
            let overlap = max(0, track.clips[i].endTime - track.clips[i + 1].startTime)
            track.clips[i].fadeOutDuration = overlap
            track.clips[i + 1].fadeInDuration = overlap
        }
        appState.show.timeline.tracks[trackIndex] = track
    }

    // MARK: - Audio import

    private func importAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .mp3]
        panel.message = "Select an audio file for the timeline"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importAudioURL(url)
    }

    private func importAudioURL(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope,
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)
            try appState.audioPlayer.loadFile(url: url)
            var ac = AudioClip()
            ac.fileName = url.lastPathComponent
            ac.fileDuration = appState.audioPlayer.fileDuration
            ac.fileBookmark = bookmark
            appState.show.timeline.audioClip = ac
            appState.audioPlayer.setVolume(appState.show.audio.masterVolume)
        } catch {
            // Load without security-scoped bookmark (sandbox may not be required in dev)
            try? appState.audioPlayer.loadFile(url: url)
            var ac = AudioClip()
            ac.fileName = url.lastPathComponent
            ac.fileDuration = appState.audioPlayer.fileDuration
            appState.show.timeline.audioClip = ac
        }
    }

    // MARK: - Layout helpers

    private var totalDuration: Double {
        let trackEnd = appState.show.timeline.tracks
            .flatMap(\.clips).map(\.endTime).max() ?? 0
        let audioEnd = appState.show.timeline.audioClip.map { $0.startTime + $0.fileDuration } ?? 0
        return max(60, trackEnd + 20, audioEnd + 10)
    }

    private var totalWidth: CGFloat {
        CGFloat(totalDuration * pixelsPerSecond)
    }

    // MARK: - Formatting

    private func formatTime(_ s: Double) -> String {
        let m = Int(s) / 60
        let sec = Int(s) % 60
        let ms = Int((s - Double(Int(s))) * 10)
        return String(format: "%02d:%02d.%d", m, sec, ms)
    }

    private func transportBtn(icon: String, tint: Color = HueBaseTheme.purple,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 22, height: 20)
                .foregroundStyle(tint)
                .background(HueBaseTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(HueBaseTheme.border, lineWidth: 1))
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }

    private var bpmFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.allowsFloats = true
        f.minimum = 20; f.maximum = 300
        f.maximumFractionDigits = 1
        return f
    }
}

// MARK: - Drag state

private struct ClipDragState {
    let clipID: UUID
    let trackIndex: Int
    let mode: Mode
    let anchorStart: Double
    let anchorDuration: Double
    let grabOffsetX: Double

    enum Mode { case move, resizeLeft, resizeRight }
}

// MARK: - Double-click to add clip extension

extension TimelineView {
    // Adds a clip at the given track row at the tapped x position
    func addClipAt(x: CGFloat, trackIndex: Int) {
        let t = max(0, Double(x) / pixelsPerSecond)
        let layers = appState.show.layers
        let hue = Double.random(in: 0...1)
        let clip = TimelineClip(
            startTime: t,
            layers: layers,
            label: layers.first?.name ?? "Clip",
            colorHue: hue
        )
        appState.show.timeline.tracks[trackIndex].clips.append(clip)
        normalizeCrossfades(trackIndex: trackIndex)
    }
}

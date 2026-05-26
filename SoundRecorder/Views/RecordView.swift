//
//  RecordView.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import SwiftUI
import AVFoundation
import Accelerate

struct RecordView: View {
    @StateObject private var vm: AudioRecorderViewModel
    @State private var recordingName: String = ""
    @State private var duration: TimeInterval = 0
    @State private var trimStart: TimeInterval = 0
    @State private var trimEnd: TimeInterval = 0
    @State private var waveformSamples: [Float] = []
    @State private var isPlayingPreview = false
    @State private var isSaving = false
    @State private var playbackDelegate = PlaybackDelegate()
    private let previewPlayer = PreviewPlayerHolder()

    init(audioManager: AudioManager) {
        _vm = StateObject(wrappedValue: AudioRecorderViewModel(audioManager: audioManager))
    }
    
    init(audioRecorderViewModel: AudioRecorderViewModel) {
        _vm = StateObject(wrappedValue: audioRecorderViewModel)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Recording Controls

                    Text("Record")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    if vm.authorizationStatus == .denied {
                        Text("Microphone access denied. Please enable it in Settings.")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text(formatTime(vm.elapsedTime))
                            .font(.system(size: 48, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    if vm.authorizationStatus == .authorized {
                        if vm.isRecording {
                            Button {
                                vm.stopRecording()
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(Color.red, lineWidth: 5)
                                        .frame(width: 120, height: 120)
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .accessibilityLabel("Stop recording")
                            .buttonStyle(PlainButtonStyle())

                            Button {
                                vm.stopRecording(save: false)
                            } label: {
                                Text("Discard")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            Button {
                                stopPreview()
                                vm.startRecording()
                                clearReviewState()
                            } label: {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text("Start")
                                            .foregroundColor(.white)
                                            .font(.title2.bold())
                                    )
                            }
                            .accessibilityLabel("Start recording")
                            .buttonStyle(PlainButtonStyle())
                        }
                    } else if vm.authorizationStatus == .notDetermined {
                        Button {
                            vm.requestPermission()
                        } label: {
                            Text("Allow Microphone")
                                .foregroundColor(.black)
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // MARK: - Review Section

                    if vm.pendingRecordingURL != nil {
                        Divider()
                            .background(Color.gray)
                            .padding(.horizontal)

                        VStack(spacing: 16) {
                            TextField("Recording name", text: $recordingName)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)

                            if !waveformSamples.isEmpty {
                                ReviewTrimSlider(
                                    trimStart: $trimStart,
                                    trimEnd: $trimEnd,
                                    duration: duration,
                                    waveformSamples: waveformSamples
                                )
                                .padding(.horizontal)
                            }

                            HStack {
                                Text(formatTimePrecise(trimStart))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Duration: \(formatTimePrecise(trimEnd - trimStart))")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(formatTimePrecise(trimEnd))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            Button {
                                if isPlayingPreview {
                                    stopPreview()
                                } else {
                                    playPreview()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isPlayingPreview ? "stop.fill" : "play.fill")
                                    Text(isPlayingPreview ? "Stop" : "Preview")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.4))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())

                            HStack(spacing: 24) {
                                Button {
                                    stopPreview()
                                    vm.discardPendingRecording()
                                    clearReviewState()
                                } label: {
                                    Text("Discard")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 14)
                                        .background(Color.red.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button {
                                    save()
                                } label: {
                                    HStack {
                                        if isSaving {
                                            ProgressView()
                                                .tint(.black)
                                                .padding(.trailing, 4)
                                        }
                                        Text("Save")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isSaving)
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: vm.pendingRecordingURL) {
            if vm.pendingRecordingURL != nil {
                loadRecording()
            }
        }
        .onAppear {
            playbackDelegate.onFinished = {
                isPlayingPreview = false
            }
        }
    }

    // MARK: - Helpers

    private func loadRecording() {
        guard let url = vm.pendingRecordingURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            duration = player.duration
            trimStart = 0
            trimEnd = player.duration
        } catch {
            duration = 0
        }
        recordingName = url.deletingPathExtension().lastPathComponent
        Task {
            let samples = await WaveformExtractor.extractSamples(from: url, count: 120)
            await MainActor.run {
                waveformSamples = samples
            }
        }
    }

    private func clearReviewState() {
        recordingName = ""
        duration = 0
        trimStart = 0
        trimEnd = 0
        waveformSamples = []
    }

    private func playPreview() {
        guard let url = vm.pendingRecordingURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = playbackDelegate
            player.currentTime = trimStart
            player.prepareToPlay()
            player.play()
            previewPlayer.player = player
            isPlayingPreview = true

            let trimDuration = trimEnd - trimStart
            DispatchQueue.main.asyncAfter(deadline: .now() + trimDuration) {
                if self.isPlayingPreview {
                    self.stopPreview()
                }
            }
        } catch {}
    }

    private func stopPreview() {
        previewPlayer.player?.stop()
        previewPlayer.player = nil
        isPlayingPreview = false
    }

    private func save() {
        stopPreview()
        isSaving = true
        Task {
            let _ = await vm.savePendingRecording(
                name: recordingName,
                trimStart: trimStart,
                trimEnd: trimEnd
            )
            await MainActor.run {
                isSaving = false
                vm.elapsedTime = 0
                clearReviewState()
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatTimePrecise(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let centiseconds = Int((time - Double(totalSeconds)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, centiseconds)
    }
}

private class PreviewPlayerHolder {
    var player: AVAudioPlayer?
}

// MARK: - Waveform & Trim Components

struct ReviewTrimSlider: View {
    @Binding var trimStart: TimeInterval
    @Binding var trimEnd: TimeInterval
    let duration: TimeInterval
    let waveformSamples: [Float]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height: CGFloat = 80

            ZStack(alignment: .leading) {
                ReviewWaveformView(samples: waveformSamples, color: .gray.opacity(0.3))
                    .frame(height: height)

                let startX = duration > 0 ? CGFloat(trimStart / duration) * width : 0
                let endX = duration > 0 ? CGFloat(trimEnd / duration) * width : width
                let trimWidth = max(0, endX - startX)

                ReviewWaveformView(samples: waveformSamples, color: .blue)
                    .frame(height: height)
                    .mask(
                        Rectangle()
                            .frame(width: trimWidth, height: height)
                            .offset(x: startX - (width - trimWidth) / 2)
                    )

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: startX, height: height)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: max(0, width - endX), height: height)
                }

                ReviewTrimHandle(color: .blue)
                    .offset(x: startX - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                trimStart = max(0, min(Double(value.location.x / width) * duration, trimEnd - 0.1))
                            }
                    )

                ReviewTrimHandle(color: .blue)
                    .offset(x: endX - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                trimEnd = max(trimStart + 0.1, min(Double(value.location.x / width) * duration, duration))
                            }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(height: height)
        }
        .frame(height: 80)
    }
}

struct ReviewWaveformView: View {
    let samples: [Float]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let barCount = samples.count
            let spacing: CGFloat = 1
            let barWidth = barCount > 0
                ? (geometry.size.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount)
                : 0
            let midY = geometry.size.height / 2

            Canvas { context, size in
                for (index, sample) in samples.enumerated() {
                    let barHeight = max(2, CGFloat(sample) * size.height)
                    let x = CGFloat(index) * (barWidth + spacing)
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: max(1, barWidth),
                        height: barHeight
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(color)
                    )
                }
            }
        }
    }
}

struct ReviewTrimHandle: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 16, height: 88)
            .overlay(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 2, height: 20)
            )
    }
}

enum WaveformExtractor {
    static func extractSamples(from url: URL, count: Int) async -> [Float] {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return []
            }

            try file.read(into: buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return [] }
            let totalFrames = Int(buffer.frameLength)
            let samplesPerBin = totalFrames / count

            guard samplesPerBin > 0 else { return [] }

            var result = [Float](repeating: 0, count: count)
            for i in 0..<count {
                let start = i * samplesPerBin
                let length = min(samplesPerBin, totalFrames - start)
                guard length > 0 else { continue }

                var rms: Float = 0
                vDSP_rmsqv(channelData.advanced(by: start), 1, &rms, vDSP_Length(length))
                result[i] = rms
            }

            let maxVal = result.max() ?? 1
            if maxVal > 0 {
                for i in 0..<result.count {
                    result[i] /= maxVal
                }
            }

            return result
        } catch {
            return []
        }
    }
}

#Preview {
    RecordView(audioRecorderViewModel: AudioRecorderViewModel(audioManager: AudioManager()))
}

//
//  AudioRecorderViewModel.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import Foundation
import AVFoundation
import Combine

class AudioRecorderViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var errorMessage: String? = nil
    @Published var pendingRecordingURL: URL? = nil

    private var recorder: AVAudioRecorder? = nil
    private var timer: Timer? = nil
    private var currentFileURL: URL? = nil
    private let audioManager: AudioManager

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        super.init()
        authorizationStatus = .authorized
    }

    func requestPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.authorizationStatus = .authorized
            }
        }
    }

    private func audioFilename() -> URL {
        let baseFilename = "Recording"
        var counter = 1
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var pendingFilename = "\(baseFilename)-\(counter).m4a"
        print(documents.appendingPathComponent(pendingFilename).path(percentEncoded: false))
        while (FileManager.default.fileExists(atPath: documents.appendingPathComponent(pendingFilename).path(percentEncoded: false))) {
            counter += 1
            pendingFilename = "\(baseFilename)-\(counter).m4a"
        }
        return documents.appendingPathComponent(pendingFilename)
    }

    func startRecording() {
        errorMessage = nil
        if pendingRecordingURL != nil {
            discardPendingRecording()
        }

        guard authorizationStatus == .authorized else {
            errorMessage = "Microphone access not granted."
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let url = audioFilename()
            currentFileURL = url

            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()

            isRecording = true
            elapsedTime = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.elapsedTime = self?.recorder?.currentTime ?? 0
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording(save: Bool = true) {
        timer?.invalidate()
        timer = nil

        recorder?.stop()
        isRecording = false

        if !save, let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
            currentFileURL = nil
        }

        if save, let url = currentFileURL {
            pendingRecordingURL = url
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // no action needed on deactivate error
        }
    }

    func savePendingRecording(name: String, trimStart: TimeInterval, trimEnd: TimeInterval) async -> Bool {
        guard let url = pendingRecordingURL else { return false }
        var recordingName = url.absoluteString
        if !name.isEmpty {
            recordingName = name
        }
        let duration = (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
        let needsTrim = trimStart > 0.05 || (duration - trimEnd) > 0.05
        
        var savedURL: URL

        if needsTrim {
            guard let trimmedURL = await audioManager.trimRecording(
                source: url,
                startTime: trimStart,
                endTime: trimEnd
            ) else { return false }
            try? FileManager.default.removeItem(at: url)
            savedURL = trimmedURL
        } else {
            savedURL = url
        }

        Task {
            let newRecord = await Recording(name: recordingName, recordingURL: savedURL)
            await audioManager.addRecording(recording: newRecord)
        }

        await MainActor.run {
            
            pendingRecordingURL = nil
            currentFileURL = nil
        }
        return true
    }

    func discardPendingRecording() {
        if let url = pendingRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        pendingRecordingURL = nil
        currentFileURL = nil
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        stopRecording(save: false)
        if let error = error {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = "An unknown recording error occurred."
        }
    }
}

//
//  AudioManager.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import Foundation
import AVFoundation
import Combine
import CoreMedia

class AudioManager: ObservableObject {
    @Published var recordingNames: [URL] = []
    @Published var recordings: [Recording] = []
    
    var audioPlayer: AVAudioPlayer?
    var audioObservers: [AudioObserver] = []

    func addRecording(recording: Recording) async {
        recordings.append(recording)
    }
    
    func deleteRecording(recording: Recording) {
        recordings.removeAll { $0 == recording }
        let url = recording.url
        try? FileManager.default.removeItem(at: url)
        notifyAudioObservers()
    }
    
    func registerAudioObserver(observer: AudioObserver) {
        audioObservers.append(observer)
    }
    
    func notifyAudioObservers() {
        for observer in audioObservers {
            observer.recordingsUpdated()
        }
    }
    
    func renameRecording(recording: Recording, to newName: String) {
        if let index = recordings.firstIndex(of: recording) {
            recordings[index].name = newName
        }
    }

    func trimRecording(source: URL, startTime: TimeInterval, endTime: TimeInterval) async -> URL? {
        let asset = AVURLAsset(url: source)
        let start = CMTime(seconds: startTime, preferredTimescale: 44100)
        let end = CMTime(seconds: endTime, preferredTimescale: 44100)
        let timeRange = CMTimeRange(start: start, end: end)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        let filename = formatter.string(from: Date()) + ".m4a"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documents.appendingPathComponent(filename)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        guard exportSession.status == .completed else { return nil }

        await MainActor.run {
            recordingNames.append(outputURL)
        }
        return outputURL
    }
}

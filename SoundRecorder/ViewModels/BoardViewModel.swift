//
//  BoardViewModel.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import Foundation
import AVFoundation
import Combine

class BoardViewModel: AudioObserver, ObservableObject {
    let audioManager: AudioManager
    @Published var soundButtons: [SoundButton] = []

    init(audioManager: AudioManager) {
        self.audioManager = audioManager
        audioManager.registerAudioObserver(observer: self)
    }
    
    func addSoundButton(title: String, recording: Recording) {
        soundButtons.append(SoundButton(title: title, recording: recording))
    }

    func removeSoundButton(id: UUID) {
        soundButtons.removeAll { $0.id == id }
    }

    func renameSoundButton(id: UUID, title: String) {
        if let index = soundButtons.firstIndex(where: { $0.id == id }) {
            soundButtons[index].title = title
        }
    }


    func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioManager.audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioManager.audioPlayer?.play()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func recordingsUpdated() {
        let updatedButtons = soundButtons.filter { audioManager.recordings.contains($0.recording) }
        soundButtons = updatedButtons
    }
}

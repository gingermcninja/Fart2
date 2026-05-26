//
//  SoundRecorderApp.swift
//  SoundRecorder2
//
//  Created by Paul McGrath on 12/3/25.
//

import SwiftUI
import AVFoundation

@main
struct SoundRecorderApp: App {
    @StateObject private var audioManager: AudioManager

    init() {
        let manager = AudioManager()
        _audioManager = StateObject(wrappedValue: manager)
        
    }

    var body: some Scene {
        WindowGroup {
            ContentView(audioManager: audioManager)
        }
    }
}

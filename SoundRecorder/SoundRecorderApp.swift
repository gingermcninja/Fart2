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
    @StateObject private var boardViewModel: BoardViewModel

    init() {
        let manager = AudioManager()
        _audioManager = StateObject(wrappedValue: manager)
        _boardViewModel = StateObject(wrappedValue: BoardViewModel(audioManager: manager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioManager)
                .environmentObject(boardViewModel)
        }
    }
}

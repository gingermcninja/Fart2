//
//  ContentView.swift
//  Fart2
//
//  Created by Paul McGrath on 12/3/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioManager: AudioManager
    @StateObject private var boardViewModel: BoardViewModel
    
    var body: some View {
        TabView {
            BoardView()
                .environmentObject(boardViewModel)
            .tabItem { Label("Playback", systemImage: "play.circle") }
            ListView()
                .environmentObject(audioManager)
            .tabItem { Label("List", systemImage: "list.bullet.circle") }
            RecordView(audioManager: audioManager)
            .tabItem { Label("Record", systemImage: "mic.circle") }
        }
    }
    
    init(audioManager: AudioManager) {
        let bvm = BoardViewModel(audioManager: audioManager)
        _audioManager = StateObject(wrappedValue: audioManager)
        _boardViewModel = StateObject(wrappedValue: bvm)
    }
}

#Preview {
    let audioManager = AudioManager()
    ContentView(audioManager: audioManager)
        .environmentObject(audioManager)
}

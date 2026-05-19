//
//  ContentView.swift
//  Fart2
//
//  Created by Paul McGrath on 12/3/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        TabView {
            let boardViewModel = BoardViewModel(audioManager: audioManager)
            BoardView().environmentObject(boardViewModel)
            .tabItem { Label("Playback", systemImage: "play.circle") }
            ListView()
            .tabItem { Label("List", systemImage: "list.bullet.circle") }
            RecordView(audioManager: audioManager)
            .tabItem { Label("Record", systemImage: "mic.circle") }
        }
    }
    
    
    
}

#Preview {
    ContentView()
        .environmentObject(AudioManager())
}

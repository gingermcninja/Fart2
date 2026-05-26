//
//  ListView.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import SwiftUI
import AVFoundation

class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    var onFinished: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.onFinished?()
        }
    }
}

struct ListView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var currentlyPlayingRecording: Recording?
    @State private var renamingRecording: Recording?
    @State private var renameText: String = ""
    @State private var playbackDelegate = PlaybackDelegate()

    var body: some View {
        NavigationStack {
            List {
                if audioManager.recordings.isEmpty {
                    Text("No recordings yet")
                        .foregroundStyle(.gray)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(audioManager.recordings, id: \.self) { recording in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recording.name)
                                        .font(.body)
                                        .foregroundColor(.white)
                                    Text(recording.url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    if currentlyPlayingRecording == recording {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                    }
                                    Button(action: {
                                        if currentlyPlayingRecording == recording {
                                            audioManager.audioPlayer?.stop()
                                            currentlyPlayingRecording = nil
                                        } else {
                                            playRecording(recording: recording)
                                        }
                                    }) {
                                        Image(systemName: currentlyPlayingRecording == recording ? "stop.circle" : "play.circle")
                                            .imageScale(.large)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.1))
                            .contentShape(Rectangle())
                            .swipeActions(edge: .leading) {
                                Button {
                                    renameText = recording.name
                                    renamingRecording = recording
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onTapGesture {
                                if currentlyPlayingRecording == recording {
                                    audioManager.audioPlayer?.stop()
                                    currentlyPlayingRecording = nil
                                } else {
                                    self.playRecording(recording: recording)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let recordingToDelete = audioManager.recordings[index]
                                audioManager.deleteRecording(recording: recordingToDelete)
                            }
                        }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Recordings")
            .preferredColorScheme(.dark)
            .onAppear {
                playbackDelegate.onFinished = {
                    currentlyPlayingRecording = nil
                }
            }
            .alert("Rename Recording", isPresented: Binding(
                get: { renamingRecording != nil },
                set: { if !$0 { renamingRecording = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingRecording = nil }
                Button("Save") {
                    guard let recording = renamingRecording, !renameText.isEmpty else { return }
                    audioManager.renameRecording(recording: recording, to: renameText)
                    renamingRecording = nil
                }
            }
        }
    }

    private func playRecording(recording: Recording) {
        do {
            audioManager.audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
            audioManager.audioPlayer?.delegate = playbackDelegate
            audioManager.audioPlayer?.prepareToPlay()
            audioManager.audioPlayer?.play()
            currentlyPlayingRecording = recording
        } catch {
            // Silently fail
        }
    }
    
    private func onTap(currentlyPlayingRecording: inout Recording?, recording: Recording, audioManager:AudioManager) {
        if currentlyPlayingRecording == recording {
            audioManager.audioPlayer?.stop()
            currentlyPlayingRecording = nil
        } else {
            self.playRecording(recording: recording)
        }
    }
     
    
}

#Preview {
    ListView()
        .environmentObject(AudioManager())
}

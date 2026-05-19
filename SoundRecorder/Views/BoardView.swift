//
//  BoardView.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 2/11/26.
//

import SwiftUI
import AVFoundation

struct BoardView: View {
    @EnvironmentObject var boardViewModel: BoardViewModel
    @State private var showingAddSheet = false
    @State private var buttonToReassign: SoundButton?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sound Board")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(boardViewModel.soundButtons) { button in
                        SoundButtonView(button: button) {
                            boardViewModel.play(url: button.recording.url)
                        } onLongPress: {
                            buttonToReassign = button
                        }
                    }

                    Button {
                        showingAddSheet = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.title)
                            Text("Add Sound")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RecordingPickerView(mode: .add, boardViewModel: boardViewModel)
        }
        .sheet(item: $buttonToReassign) { button in
            RecordingPickerView(mode: .edit(button), boardViewModel: boardViewModel)
        }
    }
}

struct SoundButtonView: View {
    let button: SoundButton
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Text(button.title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture {
                onLongPress()
            }
    }
}

// MARK: - Recording Picker

enum PickerMode: Identifiable {
    case add
    case edit(SoundButton)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let button): return button.id.uuidString
        }
    }
}

struct RecordingPickerView: View {
    let mode: PickerMode
    @State var boardViewModel: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch mode {
        case .add: return "Add Sound"
        case .edit: return "Edit Sound"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if boardViewModel.audioManager.recordings.isEmpty {
                    Text("No recordings available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(boardViewModel.audioManager.recordings, id: \.self) { recording in
                        Button {
                            selectRecording(recording: recording)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recording.url.deletingPathExtension().lastPathComponent)
                                    .font(.body)
                                Text(recording.url.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if case .edit(let button) = mode {
                    Button("Remove from Board", role: .destructive) {
                        boardViewModel.removeSoundButton(id: button.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func selectRecording(recording: Recording) {
        let name = recording.name
        
        switch mode {
        case .add:
            boardViewModel.addSoundButton(title: name, recording: recording)
        case .edit(let button):
            if let index = boardViewModel.soundButtons.firstIndex(where: { $0.id == button.id }) {
                //audioManager.soundButtons[index].title = name
                boardViewModel.soundButtons[index].recording = recording
            }
        }
        dismiss()
    }

}

#Preview {
    let audioManager = AudioManager()
    let boardViewModel = BoardViewModel(audioManager: audioManager)
    BoardView()
        //.environmentObject(audioManager)
        .environmentObject(boardViewModel)
    
}

//
//  SoundButton.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 5/8/26.
//

import Foundation

struct SoundButton: Identifiable, Equatable {
    let id: UUID
    var title: String
    var recording: Recording

    init(title: String, recording: Recording) {
        self.id = UUID()
        self.title = title
        self.recording = recording
    }
}



//
//  Recording.swift
//  SoundRecorder
//
//  Created by Paul McGrath on 5/8/26.
//

import Foundation

struct Recording: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var url: URL
    
    init(name: String, recordingURL: URL) {
        self.id = UUID()
        self.name = name
        self.url = recordingURL
    }
    
    static func == (lhs: Recording, rhs: Recording) -> Bool {
        return lhs.id == rhs.id && lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }
}

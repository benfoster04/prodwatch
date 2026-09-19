//
//  LogSheetView.swift
//  prodwatch
//
//  Created by Ben Foster on 30/07/2026.
//

import SwiftUI

struct LogSheetView: View {
    @ObservedObject var engine: TimerEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Event Log")
                .font(.title2).bold()
            
            if engine.showRun.entries.count > 0 {
                
                ModalHeaderView(engine: engine)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(engine.showRun.entries) { entry in
                        Text("[\(entry.wallClockTime.formatted(date: .omitted, time: .standard))] +\(entry.showElapsed.stopwatchFormatted) \(entry.actName) > \(entry.sectionName) - \(entry.event.rawValue)")
                            .foregroundStyle(colourByEvent(event: entry.event))
                    }
                }
                
            } else {
                Text("No show run data available.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
    
    private func colourByEvent(event: TimestampEvent) -> Color {
        return switch event {
        case .started, .resumedFromPause, .showResumed: Color.green
        case .stopped, .paused:                         Color.orange
        case .showStopped, .showCancelled:              Color.red
        case .timestamp:                                Color.blue
        case .showCompleted:                            Color.green
        case .reset, .completed:                        Color.secondary
        }
    }
    
}

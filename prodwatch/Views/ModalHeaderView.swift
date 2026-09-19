//
//  ModalHeaderView.swift
//  prodwatch
//
//  Created by Ben Foster on 30/07/2026.
//

import SwiftUI

struct ModalHeaderView: View {
    @ObservedObject var engine: TimerEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(engine.showRun.show.title)
                .font(.callout).fontWeight(.medium)
            Text("\(engine.showRun.entries.count) logged events · \(engine.showRun.totalDuration.stopwatchFormatted) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
}

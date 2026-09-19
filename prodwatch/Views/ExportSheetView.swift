//
//  ExportSheetView.swift
//  prodwatch
//
//  Created by Ben Foster on 30/07/2026.
//

import SwiftUI

struct ExportSheetView: View {
    @ObservedObject var engine: TimerEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Export Show Report")
                .font(.title2).bold()

            if engine.showRun.entries.count > 0 {
                
                ModalHeaderView(engine: engine)

                VStack(spacing: 10) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            ExportManager.export(engine.showRun, format: format)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: formatIcon(format))
                                    .frame(width: 24)
                                Text(format.label)
                                Spacer()
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("No show run data available to export.")
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
        .frame(width: 360)
    }

    private func formatIcon(_ format: ExportFormat) -> String {
        switch format {
        case .txt:  return "doc.text"
        case .json: return "curlybraces"
        case .pdf:  return "doc.richtext"
        }
    }
}

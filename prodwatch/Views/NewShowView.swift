//
//  NewShowView.swift
//  prodwatch
//
//  Created by Ben Foster on 01/06/2026.
//
import SwiftUI

struct NewShowView: View {
    let onCreate: (Show) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var title  = ""
    @State private var venue  = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Show")
                .font(.title2).bold()

            LabeledContent("Title") {
                TextField("Show title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Venue") {
                TextField("Venue", text: $venue)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Create") {
                    var newShow = Show(title: title.isEmpty ? "Untitled Show" : title)
                    newShow.venue = venue
                    onCreate(newShow)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

//
//  ContentView.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.clockFormatter.string(from: context.date))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .fixedSize()
        }
        .padding(12)
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()
}

#Preview {
    ContentView()
}

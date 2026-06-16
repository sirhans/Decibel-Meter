//
//  ContentView.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import SwiftUI

struct ContentView: View {
    let meterState: MeterState
    var closeAction: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(formattedDecibels)
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())

            Text("dB(A)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 23)
        .padding(.vertical, 13)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .fixedSize()
        .contextMenu {
            Button("Close", action: closeAction)
        }
        .padding(16)
    }

    private var formattedDecibels: String {
        guard meterState.isReceivingAudio else { return "--" }
        return meterState.decibels.formatted(.number.precision(.fractionLength(0)))
    }

    private var backgroundColor: Color {
        guard meterState.isReceivingAudio else { return .black.opacity(0.72) }

        switch meterState.decibels {
        case let decibels where decibels >= 91:
            return .red.opacity(0.78)
        case let decibels where decibels >= 88:
            return .yellow.opacity(0.78)
        case let decibels where decibels >= 70:
            return .green.opacity(0.78)
        default:
            return .black.opacity(0.72)
        }
    }
}

#Preview {
    ContentView(meterState: MeterState())
}

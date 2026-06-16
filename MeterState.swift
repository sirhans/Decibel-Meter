//
//  MeterState.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class MeterState {
    var decibels: Float = -128
    var statusText = "Starting"
    var isReceivingAudio = false
}

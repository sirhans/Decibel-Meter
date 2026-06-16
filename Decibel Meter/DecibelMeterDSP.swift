//
//  DecibelMeterDSP.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import Foundation

final class DecibelMeterDSP {
    private var levelMeter = BMLevelMeter()
    private var aWeightFilter = BMAWeightFilter()
    private var weightedSamples = [Float]()

    init(sampleRate: Float) {
        BMLevelMeter_init(&levelMeter, sampleRate)
        BMAWeightFilter_init(&aWeightFilter, sampleRate)
    }

    deinit {
        BMAWeightFilter_free(&aWeightFilter)
    }

    func slowRMSPowerDecibels(monoSamples: UnsafeBufferPointer<Float>) -> Float {
        guard let baseAddress = monoSamples.baseAddress, !monoSamples.isEmpty else {
            return -128
        }

        weightedSamples.removeAll(keepingCapacity: true)
        weightedSamples.append(contentsOf: monoSamples)

        var fastDecibels: Float = -128
        var slowDecibels: Float = -128

        weightedSamples.withUnsafeMutableBufferPointer { weightedBuffer in
            guard let weightedBaseAddress = weightedBuffer.baseAddress else { return }

            BMAWeightFilter_processMono(
                &aWeightFilter,
                baseAddress,
                weightedBaseAddress,
                weightedBuffer.count
            )

            BMLevelMeter_RMSPowerMono(
                &levelMeter,
                weightedBaseAddress,
                &fastDecibels,
                &slowDecibels,
                weightedBuffer.count
            )
        }

        return slowDecibels
    }
}

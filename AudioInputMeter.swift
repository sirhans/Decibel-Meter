//
//  AudioInputMeter.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import AVFAudio
import Foundation

final class AudioInputMeter {
    private enum AudioInputError: Error {
        case inputFormatUnavailable
    }

    private let engine = AVAudioEngine()
    private let state: MeterState
    private let calibrationOffsetDecibels: Float = 95
    private let inputStallTimeout: TimeInterval = 5
    private var dsp: DecibelMeterDSP?
    private var monoBuffer = [Float]()
    private var hasPrimedDSP = false
    private var lastBufferTime = Date()
    private var configurationObserver: NSObjectProtocol?
    private var healthCheckTimer: Timer?
    private var pendingRestartWorkItem: DispatchWorkItem?
    private var isRestarting = false

    init(state: MeterState) {
        self.state = state
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRestart(reason: "Audio changed")
        }
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        pendingRestartWorkItem?.cancel()
        healthCheckTimer?.invalidate()
        stopEngine()
    }

    func start() async {
        let hasPermission = await AVAudioApplication.requestRecordPermission()
        guard hasPermission else {
            updateState(decibels: -128, statusText: "Mic denied", isReceivingAudio: false)
            return
        }

        do {
            try startEngine()
            startHealthCheckTimer()
            updateState(decibels: -128, statusText: "Starting", isReceivingAudio: false)
        } catch {
            updateState(decibels: -128, statusText: "Mic error", isReceivingAudio: false)
        }
    }

    func stop() {
        pendingRestartWorkItem?.cancel()
        healthCheckTimer?.invalidate()
        stopEngine()
    }

    func pauseForSleep() {
        pendingRestartWorkItem?.cancel()
        stopEngine()
        updateState(decibels: -128, statusText: "Sleeping", isReceivingAudio: false)
    }

    func restartAfterWake() {
        scheduleRestart(reason: "Waking", delay: 1)
    }

    private func startEngine() throws {
        let inputNode = engine.inputNode
        try inputNode.setVoiceProcessingEnabled(false)

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioInputError.inputFormatUnavailable
        }

        let sampleRate = Float(inputFormat.sampleRate)
        dsp = DecibelMeterDSP(sampleRate: sampleRate)
        hasPrimedDSP = false
        lastBufferTime = Date()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
    }

    private func scheduleRestart(reason: String, delay: TimeInterval = 0.5) {
        pendingRestartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.restartAudioInput(reason: reason)
        }
        pendingRestartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func restartAudioInput(reason: String) {
        guard !isRestarting else { return }
        isRestarting = true
        updateState(decibels: -128, statusText: reason, isReceivingAudio: false)

        stopEngine()

        do {
            try startEngine()
        } catch {
            updateState(decibels: -128, statusText: "Mic error", isReceivingAudio: false)
        }

        isRestarting = false
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: inputStallTimeout, repeats: true) { [weak self] _ in
            self?.restartIfInputStalled()
        }
    }

    private func restartIfInputStalled() {
        guard hasPrimedDSP, engine.isRunning else { return }

        let secondsSinceLastBuffer = Date().timeIntervalSince(lastBufferTime)
        if secondsSinceLastBuffer > inputStallTimeout {
            scheduleRestart(reason: "Audio stalled")
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        lastBufferTime = Date()
        guard let dsp, let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else { return }

        monoBuffer.removeAll(keepingCapacity: true)
        monoBuffer.reserveCapacity(frameLength)

        if channelCount == 1 {
            monoBuffer.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            for frame in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frame]
                }
                monoBuffer.append(sum / Float(channelCount))
            }
        }

        guard hasPrimedDSP else {
            monoBuffer.withUnsafeBufferPointer { samples in
                for _ in 0..<100 {
                    _ = dsp.slowRMSPowerDecibels(monoSamples: samples)
                }
            }
            hasPrimedDSP = true
            return
        }

        let rawDecibels = monoBuffer.withUnsafeBufferPointer { samples in
            dsp.slowRMSPowerDecibels(monoSamples: samples)
        }
        let estimatedSPL = rawDecibels + calibrationOffsetDecibels

        Task { @MainActor [weak state] in
            state?.decibels = estimatedSPL
            state?.isReceivingAudio = true
            state?.statusText = "Listening"
        }
    }

    @MainActor
    private func updateState(
        decibels: Float? = nil,
        statusText: String,
        isReceivingAudio: Bool
    ) {
        if let decibels {
            state.decibels = decibels
        }
        state.statusText = statusText
        state.isReceivingAudio = isReceivingAudio
    }
}

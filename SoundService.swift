import Foundation
import AVFoundation

// MARK: - Sound Notification Service
final class SoundService {
    static let shared = SoundService()
    
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
    }
    
    private var audioEngine: AVAudioEngine?
    
    func play(_ type: SoundType) {
        guard enabled else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch { return }
            
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)
            
            let sampleRate: Double = 44100
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            
            let buffer: AVAudioPCMBuffer
            switch type {
            case .message:
                buffer = Self.generateTone(frequencies: [880, 1100], durations: [0.08, 0.12], sampleRate: sampleRate, format: format, volume: 0.15)
            case .connect:
                buffer = Self.generateTone(frequencies: [523, 659, 784], durations: [0.1, 0.1, 0.15], sampleRate: sampleRate, format: format, volume: 0.12)
            case .disconnect:
                buffer = Self.generateTone(frequencies: [440, 330], durations: [0.15, 0.15], sampleRate: sampleRate, format: format, volume: 0.12)
            }
            
            do {
                try engine.start()
                player.scheduleBuffer(buffer) {
                    engine.stop()
                }
                player.play()
            } catch {}
        }
    }
    
    enum SoundType { case message, connect, disconnect }
    
    private static func generateTone(frequencies: [Double], durations: [Double], sampleRate: Double, format: AVAudioFormat, volume: Float) -> AVAudioPCMBuffer {
        let totalDuration = durations.reduce(0, +)
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]
        
        var frame: AVAudioFrameCount = 0
        for (i, freq) in frequencies.enumerated() {
            let segFrames = AVAudioFrameCount(durations[i] * sampleRate)
            for f in 0..<segFrames {
                let t = Double(f) / sampleRate
                let envelope = Float(1.0 - t / durations[i]) // linear decay
                data[Int(frame)] = sin(Float(2.0 * .pi * freq * t)) * volume * envelope
                frame += 1
                if frame >= frameCount { break }
            }
        }
        return buffer
    }
}

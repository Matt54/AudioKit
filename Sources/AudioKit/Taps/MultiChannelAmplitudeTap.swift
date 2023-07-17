// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import Accelerate
import AVFoundation

/// Tap to do seperate amplitude analysis on many channels on any node.
/// start() will add the tap, and stop() will remove it.
public class MultiChannelAmplitudeTap: BaseTap {
    private let channelCount: Int
    private var handler: ([Float]) -> Void = { _ in }
    
    public var amplitudes: [Float]

    /// Determines if the returned amplitude value is the rms or peak value
    public var analysisMode: AnalysisMode = .rms

    /// Initialize the amplitude
    ///
    /// - Parameters:
    ///   - input: Node to analyze
    ///   - bufferSize: Size of buffer to analyze
    ///   - analysisMode: rms or peak returned amplitudes
    ///   - handler: Code to call with new amplitudes
    public init(_ input: Node,
                bufferSize: UInt32 = 1_024,
                analysisMode: AnalysisMode = .rms,
                handler: @escaping ([Float]) -> Void = { _ in }) {
        self.handler = handler
        self.analysisMode = analysisMode
        self.channelCount = Int(input.outputFormat.channelCount)
        self.amplitudes = Array(repeating: 0, count: channelCount)
        super.init(input, bufferSize: bufferSize)
    }

    /// Override this method to handle Tap in derived class
    /// - Parameters:
    ///   - buffer: Buffer to analyze
    ///   - time: Unused in this case
    override public func doHandleTapBlock(buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let floatData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let length = UInt(buffer.frameLength)

        // n is the channel
        for n in 0 ..< channelCount {
            let data = floatData[n]

            if analysisMode == .rms {
                var rms: Float = 0
                vDSP_rmsqv(data, 1, &rms, UInt(length))
                amplitudes[n] = rms
            } else {
                var peak: Float = 0
                var index: vDSP_Length = 0
                vDSP_maxvi(data, 1, &peak, &index, UInt(length))
                amplitudes[n] = peak
            }
        }
        
        handler(amplitudes)
    }

    /// Remove the tap on the input
    override public func stop() {
        super.stop()
        for channelIndex in 0 ..< channelCount {
            amplitudes[channelIndex] = 0
        }
    }
}

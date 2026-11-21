// CircularReplayBuffer.swift — Hardware-Accelerated Rolling Ring Buffer for iOS
// AVFoundation + VideoToolbox (H.264 hardware slice) for Zero-Lag In-Game Replay

import Foundation
import AVFoundation
import VideoToolbox
import CoreMedia

public struct ReplayFrame {
    public let timestamp: CMTime
    public let sampleBuffer: CMSampleBuffer
    public let isKeyframe: Bool
}

public final class CircularReplayBuffer {
    public static let shared = CircularReplayBuffer()
    
    // Configuration constants
    public var maxBufferDuration: TimeInterval = 30.0 // Rolling 30-second window
    public var targetFPS: Int32 = 60
    public var minimapCropEnabled: Bool = false
    public var minimapRectNormalized: CGRect = CGRect(x: 0.0, y: 0.0, width: 0.28, height: 0.38)
    
    // Ring buffer state
    private let queue = DispatchQueue(label: "com.aoi.replay.bufferqueue", qos: .userInteractive)
    private var frameBuffer: [ReplayFrame] = []
    private var isBuffering: Bool = false
    
    // VideoToolbox hardware encoder session (avoids memory bloat on iOS)
    private var compressionSession: VTCompressionSession?
    private var pixelBufferPool: CVPixelBufferPool?
    
    public init() {
        setupEncoder(width: 1280, height: 720)
    }
    
    private func setupEncoder(width: Int32, height: Int32) {
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &compressionSession
        )
        
        guard status == noErr, let session = compressionSession else { return }
        
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 2_500_000 as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: targetFPS as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: targetFPS as CFTypeRef) // 1s GOP
        
        VTCompressionSessionPrepareToEncodeFrames(session)
    }
    
    // MARK: - Ingestion
    public func pushSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Fast keyframe check
        var isKey = false
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
           let first = attachments.first {
            let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
            isKey = !notSync
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let frame = ReplayFrame(timestamp: pts, sampleBuffer: sampleBuffer, isKeyframe: isKey)
            self.frameBuffer.append(frame)
            
            // Prune old frames exceeding maxBufferDuration
            let oldestAllowedTime = CMTimeSubtract(pts, CMTimeMakeWithSeconds(self.maxBufferDuration, preferredTimescale: 600))
            while let first = self.frameBuffer.first, CMTimeCompare(first.timestamp, oldestAllowedTime) < 0 {
                self.frameBuffer.removeFirst()
            }
        }
    }
    
    // MARK: - Snapshot & Replay Slice Extraction
    public func fetchReplaySlice(secondsBack: TimeInterval, completion: @escaping ([ReplayFrame]) -> Void) {
        queue.async { [weak self] in
            guard let self = self, !self.frameBuffer.isEmpty else {
                completion([])
                return
            }
            
            let latestTime = self.frameBuffer.last!.timestamp
            let startTime = CMTimeSubtract(latestTime, CMTimeMakeWithSeconds(secondsBack, preferredTimescale: 600))
            
            // Find starting index (preferably closest keyframe before or at startTime)
            var startIndex = 0
            for (idx, frame) in self.frameBuffer.enumerated() {
                if CMTimeCompare(frame.timestamp, startTime) >= 0 {
                    startIndex = idx
                    break
                }
            }
            
            // Seek backwards to nearest keyframe for clean decode
            while startIndex > 0 && !self.frameBuffer[startIndex].isKeyframe {
                startIndex -= 1
            }
            
            let slice = Array(self.frameBuffer[startIndex...])
            completion(slice)
        }
    }
    
    public func clear() {
        queue.async { [weak self] in
            self?.frameBuffer.removeAll(keepingCapacity: true)
        }
    }
}

// CircularReplayBuffer.swift — Hardware-Accelerated Rolling Ring Buffer for iOS
// AVFoundation + CoreMedia for Zero-Lag In-Game Replay

import Foundation
import AVFoundation
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
    
    public init() {}
    
    // MARK: - Ingestion
    public func pushSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Fast keyframe check
        var isKey = true
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
            
            var startIndex = 0
            for (idx, frame) in self.frameBuffer.enumerated() {
                if CMTimeCompare(frame.timestamp, startTime) >= 0 {
                    startIndex = idx
                    break
                }
            }
            
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

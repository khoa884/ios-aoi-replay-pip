// SampleHandler.swift — ReplayKit Broadcast Upload Extension
// Collects OS-level screen buffer without modifying target game binaries

import ReplayKit
import AVFoundation

@objc(SampleHandler)
public class SampleHandler: RPBroadcastSampleHandler {
    private let replayBuffer = CircularReplayBuffer.shared
    private let sharedDefaults = UserDefaults(suiteName: "group.com.aoi.instantreplay")
    
    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        sharedDefaults?.set(true, forKey: "isBroadcastingActive")
        sharedDefaults?.synchronize()
    }
    
    public override func broadcastPaused() {
        sharedDefaults?.set(false, forKey: "isBroadcastingActive")
    }
    
    public override func broadcastResumed() {
        sharedDefaults?.set(true, forKey: "isBroadcastingActive")
    }
    
    public override func broadcastFinished() {
        sharedDefaults?.set(false, forKey: "isBroadcastingActive")
        replayBuffer.clear()
    }
    
    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            replayBuffer.pushSampleBuffer(sampleBuffer)
            
        case .audioApp, .audioMic:
            break
            
        @unknown default:
            break
        }
    }
}

// PiPReplayController.swift — Native Floating Picture-in-Picture Engine (iOS 15.0+)
// Uses AVSampleBufferDisplayLayer ContentSource to project floating replay over game

import UIKit
import AVKit
import AVFoundation

public enum PiPPlaybackMode {
    case liveMirror
    case instantReplay(seconds: TimeInterval)
}

public protocol PiPReplayControllerDelegate: AnyObject {
    func pipDidStart()
    func pipDidStop()
    func pipPlaybackFinished()
}

public final class PiPReplayController: NSObject {
    public static let shared = PiPReplayController()
    
    public weak var delegate: PiPReplayControllerDelegate?
    public private(set) var isPiPActive: Bool = false
    public var currentMode: PiPPlaybackMode = .liveMirror
    
    // Core AVKit display components
    private var pipController: AVPictureInPictureController?
    private let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var containerView: UIView?
    
    // Playback loop timer
    private var replayTimer: DispatchSourceTimer?
    private var replayFrames: [ReplayFrame] = []
    private var replayFrameIndex: Int = 0
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // Background audio entitlement requirement for PiP persistence
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[PiP] Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Layer & Controller Initialization
    public func attachToView(_ parentView: UIView) {
        self.containerView = parentView
        sampleBufferDisplayLayer.frame = parentView.bounds
        sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        parentView.layer.addSublayer(sampleBufferDisplayLayer)
        
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("[PiP] Hardware does not support Picture in Picture.")
            return
        }
        
        if #available(iOS 15.0, *) {
            let contentSource = AVPictureInPictureController.ContentSource(
                sampleBufferDisplayLayer: sampleBufferDisplayLayer,
                playbackDelegate: self
            )
            pipController = AVPictureInPictureController(contentSource: contentSource)
            pipController?.delegate = self
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
    }
    
    // MARK: - PiP Controls
    public func startPiP() {
        guard let pip = pipController, !pip.isPictureInPictureActive else { return }
        pip.startPictureInPicture()
    }
    
    public func stopPiP() {
        guard let pip = pipController, pip.isPictureInPictureActive else { return }
        pip.stopPictureInPicture()
    }
    
    public func togglePiP() {
        if isPiPActive {
            stopPiP()
        } else {
            startPiP()
        }
    }
    
    // MARK: - Frame Feeding & Replay Execution
    public func feedLiveSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isPiPActive else { return }
        
        if case .liveMirror = currentMode {
            if sampleBufferDisplayLayer.status == .failed {
                sampleBufferDisplayLayer.flush()
            }
            if sampleBufferDisplayLayer.isReadyForMoreMediaData {
                sampleBufferDisplayLayer.enqueue(sampleBuffer)
            }
        }
    }
    
    public func triggerInstantReplay(seconds: TimeInterval = 15.0) {
        currentMode = .instantReplay(seconds: seconds)
        stopReplayTimer()
        
        CircularReplayBuffer.shared.fetchReplaySlice(secondsBack: seconds) { [weak self] frames in
            guard let self = self, !frames.isEmpty else { return }
            self.replayFrames = frames
            self.replayFrameIndex = 0
            self.startReplayLoop()
        }
    }
    
    private func startReplayLoop() {
        sampleBufferDisplayLayer.flush()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16)) // ~60fps
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard self.replayFrameIndex < self.replayFrames.count else {
                self.replayFrameIndex = 0
                return
            }
            
            let frame = self.replayFrames[self.replayFrameIndex]
            if self.sampleBufferDisplayLayer.isReadyForMoreMediaData {
                self.sampleBufferDisplayLayer.enqueue(frame.sampleBuffer)
                self.replayFrameIndex += 1
            }
        }
        timer.resume()
        self.replayTimer = timer
    }
    
    private func stopReplayTimer() {
        replayTimer?.cancel()
        replayTimer = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension PiPReplayController: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
        delegate?.pipDidStart()
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
        stopReplayTimer()
        delegate?.pipDidStop()
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        isPiPActive = false
        print("[PiP] Activation error: \(error.localizedDescription)")
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate (iOS 15.0+)
@available(iOS 15.0, *)
extension PiPReplayController: AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        if playing {
            if case .instantReplay = currentMode {
                startReplayLoop()
            }
        } else {
            stopReplayTimer()
        }
    }
    
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        let duration = CMTimeMakeWithSeconds(CircularReplayBuffer.shared.maxBufferDuration, preferredTimescale: 600)
        return CMTimeRange(start: .zero, duration: duration)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return replayTimer == nil
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Handle floating window resize
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completionHandler: @escaping () -> Void) {
        let seconds = CMTimeGetSeconds(skipInterval)
        triggerInstantReplay(seconds: abs(seconds) > 0 ? abs(seconds) : 15.0)
        completionHandler()
    }
}

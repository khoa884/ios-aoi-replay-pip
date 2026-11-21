// MainViewController.swift — In-Game Highlight & Floating PiP Controller Dashboard
// Manages ReplayKit System Broadcast Picker, UI Controls, and Floating Overlay Lifecycle

import UIKit
import ReplayKit
import AVKit

public class MainViewController: UIViewController {
    
    // UI Elements
    private let statusLabel = UILabel()
    private let broadcastPicker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
    private let pipPreviewContainer = UIView()
    private let togglePiPButton = UIButton(type: .system)
    private let replay15sButton = UIButton(type: .system)
    private let replay30sButton = UIButton(type: .system)
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Attach PiP controller to preview container
        PiPReplayController.shared.attachToView(pipPreviewContainer)
        PiPReplayController.shared.delegate = self
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pipPreviewContainer.layer.sublayers?.first?.frame = pipPreviewContainer.bounds
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        
        // Status Label
        statusLabel.text = "AOI In-Game Replay & PiP Controller"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 18, weight: .bold)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Broadcast Picker Setup (points to Broadcast Upload Extension)
        broadcastPicker.preferredExtension = "com.aoi.instantreplay.upload-extension"
        broadcastPicker.showsMicrophoneButton = false
        broadcastPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(broadcastPicker)
        
        // Preview View Container (where PiP spawns from)
        pipPreviewContainer.backgroundColor = .black
        pipPreviewContainer.layer.cornerRadius = 12
        pipPreviewContainer.layer.masksToBounds = true
        pipPreviewContainer.layer.borderColor = UIColor.systemGreen.cgColor
        pipPreviewContainer.layer.borderWidth = 1.0
        pipPreviewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pipPreviewContainer)
        
        // Toggle PiP Button
        togglePiPButton.setTitle("Bật / Tắt Cửa Sổ Nổi (PiP)", for: .normal)
        togglePiPButton.setTitleColor(.white, for: .normal)
        togglePiPButton.backgroundColor = UIColor.systemBlue
        togglePiPButton.layer.cornerRadius = 8
        togglePiPButton.addTarget(self, action: #selector(handleTogglePiP), for: .touchUpInside)
        togglePiPButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(togglePiPButton)
        
        // Instant Replay Buttons
        replay15sButton.setTitle("Tua Lại 15s (Combat)", for: .normal)
        replay15sButton.setTitleColor(.white, for: .normal)
        replay15sButton.backgroundColor = UIColor.systemIndigo
        replay15sButton.layer.cornerRadius = 8
        replay15sButton.addTarget(self, action: #selector(handleReplay15s), for: .touchUpInside)
        replay15sButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(replay15sButton)
        
        replay30sButton.setTitle("Tua Lại 30s", for: .normal)
        replay30sButton.setTitleColor(.white, for: .normal)
        replay30sButton.backgroundColor = UIColor.systemTeal
        replay30sButton.layer.cornerRadius = 8
        replay30sButton.addTarget(self, action: #selector(handleReplay30s), for: .touchUpInside)
        replay30sButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(replay30sButton)
        
        // Auto-layout Constraints
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            pipPreviewContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            pipPreviewContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pipPreviewContainer.widthAnchor.constraint(equalToConstant: 280),
            pipPreviewContainer.heightAnchor.constraint(equalToConstant: 160),
            
            broadcastPicker.topAnchor.constraint(equalTo: pipPreviewContainer.bottomAnchor, constant: 20),
            broadcastPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            broadcastPicker.widthAnchor.constraint(equalToConstant: 64),
            broadcastPicker.heightAnchor.constraint(equalToConstant: 64),
            
            togglePiPButton.topAnchor.constraint(equalTo: broadcastPicker.bottomAnchor, constant: 20),
            togglePiPButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            togglePiPButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            togglePiPButton.heightAnchor.constraint(equalToConstant: 44),
            
            replay15sButton.topAnchor.constraint(equalTo: togglePiPButton.bottomAnchor, constant: 12),
            replay15sButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            replay15sButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            replay15sButton.heightAnchor.constraint(equalToConstant: 44),
            
            replay30sButton.topAnchor.constraint(equalTo: replay15sButton.bottomAnchor, constant: 12),
            replay30sButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            replay30sButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            replay30sButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Actions
    @objc private func handleTogglePiP() {
        PiPReplayController.shared.togglePiP()
    }
    
    @objc private func handleReplay15s() {
        PiPReplayController.shared.triggerInstantReplay(seconds: 15.0)
    }
    
    @objc private func handleReplay30s() {
        PiPReplayController.shared.triggerInstantReplay(seconds: 30.0)
    }
}

// MARK: - PiPReplayControllerDelegate
extension MainViewController: PiPReplayControllerDelegate {
    public func pipDidStart() {
        togglePiPButton.setTitle("Đang Hiện Cửa Sổ PiP (Bấm để Ẩn)", for: .normal)
        togglePiPButton.backgroundColor = UIColor.systemOrange
    }
    
    public func pipDidStop() {
        togglePiPButton.setTitle("Bật Cửa Sổ Nổi (PiP)", for: .normal)
        togglePiPButton.backgroundColor = UIColor.systemBlue
    }
    
    public func pipPlaybackFinished() {
        // Return to live mirror mode
    }
}

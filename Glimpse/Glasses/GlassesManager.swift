import Foundation
import Combine
import WearablesKit

enum GlassesState {
    case disconnected
    case scanning
    case connecting
    case connected
    case streaming
    case error(String)
}

@Observable
final class GlassesManager {

    var state: GlassesState = .disconnected
    var latestFrame: Data? = nil  // JPEG data from camera

    private var deviceManager: WearablesDeviceManager?
    private var connectedDevice: WearablesDevice?
    private var streamSession: StreamSession?
    private var frameStreamTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        deviceManager = WearablesDeviceManager()
        deviceManager?.delegate = self
        state = .scanning
        deviceManager?.startDiscovery()
    }

    func stop() {
        frameStreamTask?.cancel()
        frameStreamTask = nil
        streamSession = nil
        connectedDevice = nil
        deviceManager?.stopDiscovery()
        state = .disconnected
    }

    // MARK: - Streaming

    private func startStreaming(device: WearablesDevice) {
        frameStreamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await device.startStreamSession()
                await MainActor.run { self.streamSession = session; self.state = .streaming }

                for await frame in session.frames {
                    guard !Task.isCancelled else { break }
                    await MainActor.run { self.latestFrame = frame.jpegData }
                }
            } catch {
                await MainActor.run {
                    self.state = .error("Stream failed: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Capture the current frame on demand (called when user finishes speaking).
    func captureCurrentFrame() -> Data? {
        return latestFrame
    }
}

// MARK: - WearablesDeviceManagerDelegate

extension GlassesManager: WearablesDeviceManagerDelegate {

    func deviceManager(_ manager: WearablesDeviceManager, didDiscover device: WearablesDevice) {
        state = .connecting
        manager.stopDiscovery()
        device.delegate = self
        device.connect()
    }

    func deviceManager(_ manager: WearablesDeviceManager, didFailWithError error: Error) {
        state = .error(error.localizedDescription)
    }
}

// MARK: - WearablesDeviceDelegate

extension GlassesManager: WearablesDeviceDelegate {

    func deviceDidConnect(_ device: WearablesDevice) {
        connectedDevice = device
        state = .connected
        startStreaming(device: device)
    }

    func deviceDidDisconnect(_ device: WearablesDevice) {
        frameStreamTask?.cancel()
        connectedDevice = nil
        state = .disconnected
    }

    func device(_ device: WearablesDevice, didFailToConnectWithError error: Error) {
        state = .error(error.localizedDescription)
    }
}

import Network
import Foundation
import os

@Observable final class NetworkState {
    
    @MainActor var connected: Bool = true

    private var monitor: NWPathMonitor?

    init() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                Log.debug("NetworkState", "NetworkMonitor: \(path)")
                if path.status == .satisfied {
                    self.connected = true
                } else {
                    self.connected = false
                }
            }
        }
        monitor?.start(queue: DispatchQueue.global())
    }
}

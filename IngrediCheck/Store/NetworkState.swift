import Network
import Foundation

@Observable final class NetworkState {
    
    @MainActor var connected: Bool = true

    private var monitor: NWPathMonitor?

    init() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { path in
            DispatchQueue.main.async {
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

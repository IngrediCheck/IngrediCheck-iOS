//
//  ToastManager.swift
//  IngrediCheck
//
//  Created by Auto-Agent on 09/01/26.
//

import SwiftUI
import Observation

public enum ToastType {
    case info
    case success
    case error
    case warning
    
    public var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
    
    public var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

public struct ToastData: Equatable {
    public let message: String
    public let type: ToastType
    public let duration: TimeInterval
    
    public init(message: String, type: ToastType, duration: TimeInterval) {
        self.message = message
        self.type = type
        self.duration = duration
    }
    
    public static func == (lhs: ToastData, rhs: ToastData) -> Bool {
        return lhs.message == rhs.message && lhs.type == rhs.type
    }
}

@Observable
@MainActor
final class ToastManager {
    // Singleton instance
    static let shared = ToastManager()
    
    var toast: ToastData?
    var isPresented: Bool = false
    
    // Private initializer to prevent external instantiation
    private init() {}
    
    func show(message: String, type: ToastType = .info, duration: TimeInterval = 3.0) {
        self.toast = ToastData(message: message, type: type, duration: duration)
        withAnimation(.spring()) {
            self.isPresented = true
        }
        
        if duration > 0 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                dismiss()
            }
        }
    }
    
    func dismiss() {
        withAnimation(.spring()) {
            self.isPresented = false
        }
        // Small delay to allow animation to finish before clearing data
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self.toast = nil
        }
    }
}

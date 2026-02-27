//
//  EnterYourInviteCode.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 31/12/25.
//
import SwiftUI

struct EnterYourInviteCode : View {
    @Environment(FamilyStore.self) private var familyStore
    @Environment(AppNavigationCoordinator.self) private var coordinator
    @Environment(AuthController.self) private var authController
    @State private var isVerifying: Bool = false
    @State var code: [String] = Array(repeating: "", count: 6)
    @State private var isError: Bool = false
    @State private var shouldFocus: Bool = false
    @State private var shouldClear: Bool = false
    let yesPressed: (() -> Void)?
    let noPressed: (() -> Void)?
    
    // Computed property to check if all 6 characters are entered
    private var isCodeComplete: Bool {
        code.allSatisfy { !$0.isEmpty }
    }
    
    // Computed property for button title
    private var buttonTitle: String {
        if isError && isCodeComplete {
            return "Start Over"
        }
        return "Verify & Continue"
    }
    
    init(yesPressed: (() -> Void)? = nil, noPressed: (() -> Void)? = nil) {
        self.yesPressed = yesPressed
        self.noPressed = noPressed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Text("Enter your invite code")
                        .font(NunitoFont.bold.size(22))
                        .foregroundStyle(.grayScale150)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        coordinator.navigateInBottomSheet(.whosThisFor)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("This connects you to your family or shared\nIngrediCheck space.")
                    .font(ManropeFont.medium.size(12))
                    .foregroundStyle(.grayScale120)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
            
            InviteTextField(code: $code, isError: $isError, shouldFocus: $shouldFocus, shouldClear: $shouldClear)
                .padding(.bottom, 12)
            
            if isError {
                Text("Hmm, that code didn't work. Check it and try again.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.red)
                    .padding(.bottom, 44)
            } else {
                Text("You can add this later if you receive one.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
                    .padding(.bottom, 44)
            }
            
            HStack(spacing: 16) {
                
                Spacer()
                
                Button {
                    // If error occurred and button shows "Start Over", reset the form
                    if isError && isCodeComplete {
                        // Clear all code
                        code = Array(repeating: "", count: 6)
                        isError = false
                        // Trigger clear and focus to first box and show keyboard
                        shouldClear = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            shouldClear = false
                            shouldFocus = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                shouldFocus = false
                            }
                        }
                        return
                    }
                    
                    let entered = code.joined().trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        // Require a full 6-character code
                        guard entered.count == 6 else {
                            print("[EnterYourInviteCode] Invalid code length: \(entered.count)")
                            await MainActor.run { isError = true }
                            return
                        }
                        
                        await MainActor.run {
                            isVerifying = true
                            isError = false
                        }
                        
                        // Ensure user is authenticated (sign in anonymously if needed) before joining
                        if await authController.signInState != .signedIn {
                            print("[EnterYourInviteCode] User not authenticated, signing in anonymously...")
                            await authController.signIn()
                            
                            // Wait a moment for session to be established
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            // Verify we're now signed in
                            if await authController.signInState != .signedIn {
                                print("[EnterYourInviteCode] ❌ Failed to sign in anonymously")
                                await MainActor.run {
                                    isVerifying = false
                                    isError = true
                                }
                                return
                            }
                            print("[EnterYourInviteCode] ✅ Successfully signed in anonymously")
                        }
                        
                        print("[EnterYourInviteCode] Calling familyStore.join with code=\(entered)")
                        await familyStore.join(inviteCode: entered)
                        
                        await MainActor.run {
                            isVerifying = false
                            
                            if familyStore.family != nil, familyStore.errorMessage == nil {
                                print("[EnterYourInviteCode] Join success, proceeding to next step")
                                isError = false
                                yesPressed?()
                            } else {
                                print("[EnterYourInviteCode] Join failed, error=\(familyStore.errorMessage ?? "nil")")
                                isError = true
                            }
                        }
                    }
                } label: {
                    GreenCapsule(
                        title: buttonTitle,
                        isLoading: isVerifying,
                        isDisabled: isVerifying || !isCodeComplete
                    )
                }
                .disabled(isVerifying || !isCodeComplete)
                
                Spacer()
            }
            .padding(.bottom, 20)
            LegalDisclaimerView()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
        .navigationBarBackButtonHidden(true)
        .dismissKeyboardOnTap()
    }

    struct InviteTextField: View {
        @Binding var code: [String]
        @Binding var isError: Bool
        @Binding var shouldFocus: Bool
        @Binding var shouldClear: Bool
        @State private var input: String = ""
        @FocusState private var isFocused: Bool

        private let boxSize = CGSize(width: 44, height: 50)
        private var nextIndex: Int { min(code.firstIndex(where: { $0.isEmpty }) ?? 5, 5) }

        var body: some View {
            ZStack {
                // Hidden TextField that captures all input and backspace behavior
                TextField("", text: $input)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .keyboardType(.asciiCapable)
                    .focused($isFocused)
                    .onChange(of: input) { newValue in
                        // Allow only A-Z and 0-9, convert to uppercase, and limit to 6 chars
                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                        let trimmed = String(filtered.prefix(6))
                        if trimmed != newValue { input = trimmed }

                        let chars = Array(trimmed)
                        for i in 0..<6 {
                            if i < chars.count {
                                code[i] = String(chars[i])
                            } else {
                                code[i] = ""
                            }
                        }
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .onChange(of: shouldFocus) { newValue in
                        if newValue {
                            isFocused = true
                        }
                    }
                    .onChange(of: shouldClear) { newValue in
                        if newValue {
                            input = ""
                        }
                    }

                // Visual OTP boxes
                HStack(spacing: 14) {
                    HStack(spacing: 8) {
                        box(0)
                        box(1)
                        box(2)
                    }

                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FFE2E0") : .grayScale40)
                        .frame(width: 12, height: 2.5)

                    HStack(spacing: 8) {
                        box(3)
                        box(4)
                        box(5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }
            .onAppear {
                // Pre-fill input if parent provided existing code
                input = code.joined().uppercased()
            }
            .onChange(of: isError) { newValue in
                // When error is cleared, ensure focus is maintained
                if !newValue && code.allSatisfy({ $0.isEmpty }) {
                    isFocused = true
                }
            }
        }

        @ViewBuilder
        private func box(_ index: Int) -> some View {
            ZStack {
                let isFilled = !code[index].isEmpty
                let isActive = isFilled || (isFocused && index == nextIndex)
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FFE2E0") : isActive ? .secondary200 : .grayScale40)
                    .frame(width: boxSize.width, height: boxSize.height)
                    .shadow(color: (isFocused && index == nextIndex) ? Color(hex: "C7C7C7").opacity(0.25) : .clear, radius: 9, x: 0, y: 4)

                // Character for this box (if any)
                Text(code[index])
                    .font(NunitoFont.semiBold.size(22))
                    .foregroundStyle(isError && !code.last!.isEmpty ? Color(hex: "FF1100") : .grayScale150)
            }
        }
    }
}

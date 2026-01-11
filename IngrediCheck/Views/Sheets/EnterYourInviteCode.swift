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
    @State private var isVerifying: Bool = false
    @State var code: [String] = Array(repeating: "", count: 6)
    @State private var isError: Bool = false
    let yesPressed: (() -> Void)?
    let noPressed: (() -> Void)?
    
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
                        coordinator.navigateInBottomSheet(.doYouHaveAnInviteCode)
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
            
            InviteTextField(code: $code, isError: $isError)
                .padding(.bottom, 12)
            
            if isError {
                Text("We couldn't verify your code. Please try again..")
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
                Button {
                    noPressed?()
                } label: {
                    Text("No, continue")
                        .font(NunitoFont.semiBold.size(16))
                        .foregroundStyle(.grayScale110)
                        .frame(height: 52)
                        .frame(minWidth: 152)
                        .frame(maxWidth: .infinity)
                        .background(.grayScale40, in: .capsule)
                }
                
                Button {
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
                        
                        print("[EnterYourInviteCode] Calling familyStore.join with code=\(entered.lowercased())")
                        await familyStore.join(inviteCode: entered.lowercased())
                        
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
                        title: "Verify & Continue",
                        isLoading: isVerifying,
                        isDisabled: isVerifying
                    )
                }
                .disabled(isVerifying)
            }
            .padding(.bottom, 20)
            HStack{
                Image("jam-sheld-half")
                    .frame(width: 16, height: 16)
                Text("By continuing, you agree to our Terms & Privacy Policy.")
                    .font(ManropeFont.regular.size(12))
                    .foregroundStyle(.grayScale100)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .overlay(
//            RoundedRectangle(cornerRadius: 4)
//                .fill(.neutral500)
//                .frame(width: 60, height: 4)
//                .padding(.top, 11)
//            , alignment: .top
//        )
        .navigationBarBackButtonHidden(true)
    }

    struct InviteTextField: View {
        @Binding var code: [String]
        @Binding var isError: Bool
        @State private var input: String = ""
        @FocusState private var isFocused: Bool

        private let boxSize = CGSize(width: 44, height: 50)
        private var nextIndex: Int { min(code.firstIndex(where: { $0.isEmpty }) ?? 5, 5) }

        var body: some View {
            ZStack {
                // Hidden TextField that captures all input and backspace behavior
                TextField("", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($isFocused)
                    .onChange(of: input) { newValue in
                        // Allow only A-Z and 0-9, uppercase, and limit to 6 chars
                        let filtered = newValue.filter { $0.isLetter || $0.isNumber }
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

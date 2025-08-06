//
//  PreferenceList.swift
//  IngrediCheck
//
//  Created by Gunjan Haldar   on 05/08/25.
//

import SwiftUI

struct PreferenceList: View {
    
    @FocusState var isFocused: Bool
    @StateObject var vm = PreferenceListViewModel()
    @State private var preferenceExamples = PreferenceExamples()
    @State var activeSheet: PreferenceListActiveSheets?
    
    @Environment(DietaryPreferences.self) var dp
    
    var body: some View {
        VStack {
            HStack {
                Image("Ellipse-image")
                    .resizable()
                    .frame(width: 40, height: 40)
                
                Spacer()
                
                Menu {
                    Button {
                        activeSheet = .createNewList
                        print("New preference list")
                    } label: {
                        Label("New preference list", systemImage: "plus")
                    }

                    Button {
                        activeSheet = .listFeatures
                        print("List features")
                    } label: {
                        Label("List features", systemImage: "pencil")
                    }

                } label: {
                    HStack {
                        Text("Preference List")
                            .font(.headline)
                        Image(systemName: "chevron.down")
                    }
                }
                .foregroundStyle(.black)
                
                Spacer()
                
                HStack {
                    Button {
                        activeSheet = .share
                    } label: {
                        Image("arrow-export")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding(.trailing, 8)
                    }
                    .foregroundStyle(.black)
                    
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            
            VStack {
                ColaboratorCard()
                    .padding([.horizontal, .top], 16)
                
                textInputField
                
                EmptyPreferencesView()
            }
            .animation(.easeInOut)
            
        }
        .sheet(item: $activeSheet, content: { sheet in
            switch sheet {
            case .createNewList:
                CreateNewList()
                    .presentationDetents([.fraction(0.65)])
            case .editList:
                Text("edit list")
            case .listFeatures:
                ListFeatures()
                    .presentationDetents([.fraction(0.2)])
            case .share:
                ShareListSheet(url: URL(string: "https://example.com/list-share")!)
                    .presentationDetents([.fraction(0.35)])
            }
        })
        .ignoresSafeArea()
    }
    
    private var validationStatus: some View {
        HStack(spacing: 5) {
            switch dp.validationResult {
            case .validating:
                Text("Thinking")
                    .foregroundStyle(.paletteAccent)
                ProgressView()
            case .failure(let string):
                Text(string)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            case .idle, .success:
                EmptyView()
            }
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal)
    }
    
    private var textInputField: some View {
        @Bindable var dp = dp
        func borderColor(for result: ValidationResult) -> Color {
            switch result {
            case .validating:
                return .paletteAccent
            case .failure:
                return .red
            case .success, .idle:
                return .clear
            }
        }
        return VStack(spacing: 5) {
            TextField(preferenceExamples.placeholder, text: $dp.newPreferenceText, axis: .vertical)
                .focused($isFocused)
                .padding()
                .padding(.trailing)
                .background {
                    Group {
                        if isFocused {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .stroke(Color.paletteAccent, lineWidth: 1)
                                .shadow(color: Color.paletteAccent.opacity(1), radius: 20)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Material.ultraThin)
                                .stroke(borderColor(for: dp.validationResult), lineWidth: 1)
                        }
                    }
                }
                .overlay(
                    HStack {
                        if !dp.newPreferenceText.isEmpty {
                            Button(action: {
                                dp.clearNewPreferenceText()
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                        .padding(.vertical)
                        .padding(.horizontal, 7)
                    ,
                    alignment: .topTrailing
                )
                .padding(.horizontal)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(action: {
                            dp.cancelInEditPreference()
                            isFocused = false
                        }, label: {
                            Text("Cancel")
                                .fontWeight(.bold)
                        })
                    }
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if newValue {
                        dp.inputActive()
                    }
                }
                .onEnter($of: $dp.newPreferenceText, isFocused: $isFocused) {
                    dp.inputComplete()
                }
            validationStatus
        }
    }
}

struct CreateNewList: View {
    @State var name: String = ""
    @State var description: String = ""
    var body: some View {
        VStack {
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray)
                .frame(width: UIScreen.main.bounds.width / 4, height: 5)
                .padding(.bottom, 24)
                .padding(.top, 16)
            
            Text("Create new list")
                .fontWeight(.semibold)
                .font(.title3)
                .padding(.bottom, 20)
            
            
            
            VStack(alignment: .leading) {
                Text("List name")
                    .font(.headline)
                    .padding(.bottom, 8)
                TextField("Name the list", text: $name)
                    .padding()
                    .background(.gray.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.bottom, 8)
                Text("\(name.count)/20")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.8))
                
                    .padding(.bottom, 24)
                
                
                Text("Description (Optional)")
                    .font(.headline)
                    .padding(.bottom, 8)
                TextField("Give the list a description", text: $description)
                    .padding()
                    .background(.gray.opacity(0.1))
                    .cornerRadius(6)
                    .padding(.bottom, 8)
                Text("\(description.count)/150")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.8))
            }
            .padding(.bottom, 47)
            
            Button {
                print("Create new list")
            } label: {
                Text("Create new list")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding()
                    .background((name.count > 3) ? Color.black : Color.gray)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
            .disabled(name.count < 4)

        }
        .padding(.horizontal,16)
    }
}

struct ListFeatures: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray)
                .frame(width: UIScreen.main.bounds.width / 4, height: 5)
                .padding(.bottom, 32)
            
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    // Edit action
                    print("Edit")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .frame(width: 20, alignment: .leading) // 👈 fixed width
                            .padding(.trailing, 10)
                        Text("Edit list")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.title3)
                .foregroundStyle(.black)

                Divider()

                Button {
                    // Leave action
                    print("Leave")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .frame(width: 20, alignment: .leading) // 👈 same width
                            .padding(.trailing, 10)
                        Text("Leave list")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.title3)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
        }
        
    }

}

struct ShareListSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false
    @State private var email: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.5))
                .frame(width: UIScreen.main.bounds.width / 4, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            Text("Share list")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.bottom, 20)
            
            HStack(spacing: 8) {
                TextField("Enter email address", text: $email)
                    .padding(12)
                    .frame(height: 40)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .font(.subheadline)
                Button("Send invite") {
                    // Invite action
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 100, height: 40)
                .background(Color(.systemGray4))
                .foregroundColor(.black)
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            
            Text("or")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack(spacing: 32) {
                VStack {
                    Button(action: { isSharing = true }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                            Image("arrow-export")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                    }
                    .sheet(isPresented: $isSharing) {
                        ActivityView(activityItems: [url])
                            .presentationDetents([.medium])
                    }
                    Text("Share")
                        .font(.caption)
                        .foregroundColor(.black)
                }

                VStack {
                    Button(action: {
                        UIPasteboard.general.string = url.absoluteString
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                            Image(systemName: "link")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                    }
                    Text("Copy Link")
                        .font(.caption)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)

                VStack {
                    Button(action: {
                        // QR code action
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                            Image(systemName: "qrcode")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        }
                    }
                    Text("QR code")
                        .font(.caption)
                        .foregroundColor(.black)
                }
            }
            .foregroundStyle(.black)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PreferenceList()
}

//
//  MainCanvasView.swift
//  IngrediCheckPreview
//
//  Created by Gunjan Haldar   on 15/10/25.
//

import SwiftUI

extension OnboardingScreenId: Identifiable {
	var id: String { rawValue }
}

struct MainCanvasView: View {
    
	@StateObject private var store: Onboarding
	@State private var presentedOnboardingSheet: OnboardingScreenId? = nil
    
    @State var preferences: Preferences = Preferences()
	
	init(flow: OnboardingFlowType) {
		_store = StateObject(wrappedValue: Onboarding(onboardingFlowtype: flow))
	}
    
    @State var goToHomeScreen: Bool = false
    
    var body: some View {
        ZStack {
            
            CustomSheet(item: $presentedOnboardingSheet,
                        cornerRadius: 34,
                        heightsForItem: { sheet in
                switch sheet {
                case .allergies:
                    (min: 443, max: 444)
                case .intolerances:
                    (min: 304, max: 305)
                case .healthConditions:
                    (min: 393, max: 394)
                case .lifeStage:
                    (min: 422, max: 423)
                case .region:
                    (min: 334, max: 335)
                case .aviod:
                    (min: 412, max: 413)
                case .lifeStyle:
                    (min: 370, max: 371)
                case .nutrition:
                    (min: 401, max: 402)
                case .ethical:
                    (min: 432, max: 433)
                case .taste:
                    (min: 416, max: 417)
                }
            }) { sheet in
                switch sheet {
                case .allergies:
                    Allergies(onboardingFlowType: store.onboardingFlowtype)
                case .intolerances:
                    Intolerances(onboardingFlowType: store.onboardingFlowtype)
                case .healthConditions:
                    HealthConditions(onboardingFlowType: store.onboardingFlowtype)
                case .lifeStage:
                    LifeStage(onboardingFlowType: store.onboardingFlowtype)
                case .region:
                    Region(onboardingFlowType: store.onboardingFlowtype)
                case .aviod:
                    Avoid(onboardingFlowType: store.onboardingFlowtype)
                case .lifeStyle:
                    LifeStyle(onboardingFlowType: store.onboardingFlowtype)
                case .nutrition:
                    Nutrition(onboardingFlowType: store.onboardingFlowtype)
                case .ethical:
                    Ethical(onboardingFlowType: store.onboardingFlowtype)
                case .taste:
                    Taste(onboardingFlowType: store.onboardingFlowtype)
                }
            }
            
            VStack(spacing: 0) {
                CustomIngrediCheckProgressBar()
                
                CanvasTagBar()
                    .padding(.bottom, 16)
                
                
                RoundedRectangle(cornerRadius: 24)
                    .foregroundStyle(.white)
                    .shadow(color: .gray.opacity(0.3), radius: 9, x: 0, y: 0)
                    .frame(width: UIScreen.main.bounds.width * 0.9)
                    .overlay(
                        VStack {
                            
                                Button(action: {
                                    if store.currentScreen.screenId.rawValue == "taste" {
                                        presentedOnboardingSheet = nil
                                        goToHomeScreen = true
                                    } else {
                                        store.next()
                                    }
                                    
                                }, label: {
                                    Text("Next")
                                })
                            
                            
                            
                            
                            Spacer()
                            Spacer()
                        }
                        
                    )
                
                
                NavigationLink(isActive: $goToHomeScreen) {
                    HomeView()
                } label: {
                    EmptyView()
                }

            }
            
        }
		.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                presentedOnboardingSheet = store.currentScreen.screenId
            }
		}
		.onChange(of: store.currentScreenIndex) { _ in
			presentedOnboardingSheet = store.currentScreen.screenId
		}
		.onChange(of: store.currentSectionIndex) { _ in
			presentedOnboardingSheet = store.currentScreen.screenId
		}
    }
}

func onboardingSheetTitle(title: String) -> some View {
    Group {
        (Text("Q. ")
            .font(ManropeFont.bold.size(20))
            .foregroundStyle(.grayScale70)
        +
        Text(title)
            .font(NunitoFont.bold.size(20))
            .foregroundStyle(.grayScale150))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func onboardingSheetSubtitle(subtitle: String, onboardingFlowType: OnboardingFlowType) -> some View {
    if onboardingFlowType == .individual {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale100)
    } else {
        Text(subtitle)
            .font(ManropeFont.regular.size(14))
            .foregroundStyle(.grayScale120)
    }
}

func onboardingSheetFamilyMemberSelectNote() -> some View {
    HStack(alignment: .center, spacing: 0) {
        
        Image(.yellowBulb)
            .resizable()
            .frame(width: 22, height: 26)
        
        Text("Select members one by one to personalize their choices.")
            .font(ManropeFont.regular.size(12))
            .foregroundStyle(.grayScale100)
    }
}

#Preview {
	MainCanvasView(flow: .individual)
}

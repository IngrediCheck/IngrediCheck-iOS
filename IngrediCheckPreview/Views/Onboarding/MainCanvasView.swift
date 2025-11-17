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
	@Environment(AppNavigationCoordinator.self) private var coordinator
	
	init(flow: OnboardingFlowType) {
		_store = StateObject(wrappedValue: Onboarding(onboardingFlowtype: flow))
	}
    
    var body: some View {
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
                                coordinator.showCanvas(.home)
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
        }
		.onAppear {
            coordinator.setCanvasRoute(.mainCanvas(flow: store.onboardingFlowtype))
            DispatchQueue.main.async {
                updateBottomSheetForCurrentScreen()
            }
		}
		.onChange(of: store.currentScreenIndex) { _ in
			updateBottomSheetForCurrentScreen()
		}
		.onChange(of: store.currentSectionIndex) { _ in
			updateBottomSheetForCurrentScreen()
		}
    }
    
    private func updateBottomSheetForCurrentScreen() {
        let screenId = store.currentScreen.screenId
        let bottomSheetRoute: BottomSheetRoute
        
        switch screenId {
        case .allergies:
            bottomSheetRoute = .allergies
        case .intolerances:
            bottomSheetRoute = .intolerances
        case .healthConditions:
            bottomSheetRoute = .healthConditions
        case .lifeStage:
            bottomSheetRoute = .lifeStage
        case .region:
            bottomSheetRoute = .region
        case .aviod:
            bottomSheetRoute = .avoid
        case .lifeStyle:
            bottomSheetRoute = .lifeStyle
        case .nutrition:
            bottomSheetRoute = .nutrition
        case .ethical:
            bottomSheetRoute = .ethical
        case .taste:
            bottomSheetRoute = .taste
        }
        
        coordinator.navigateInBottomSheet(bottomSheetRoute)
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


//  OnboardingView.swift
//  JataYuk

//  Created by Stanley Pratama Teguh on 29/07/26.


import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: Store<RootState, RootAction>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("VolcanoBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * 0.85
                    )
                    .clipped()
                    .frame(
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                
                VStack(spacing: 80) {
                    Image("Title")
                        .frame(alignment: .center
                        )
                    exploreButton
                }
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.52)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private var exploreButton: some View {
        Button {
            store.send(.onboarding(.letsExploreTapped))
        } label: {
            Text("Let's Explore!")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 30)

                
        }
        .buttonStyle(.glassProminent)
        .tint(
            Color(
                red: 0.949,
                green: 0.729,
                blue: 0.216
            )
        )
        .accessibilityLabel("Let's Explore")
    }
}

#Preview(traits: .landscapeLeft) {
    OnboardingView(
        store: Store(
            initialState: RootState(),
            reducer: rootReducer,
            environment: RootEnvironment()
        )
    )
}


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
                //.font(.custom("Fredoka-Bold", size: 20))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 30)
                .glassEffect(.regular.interactive().tint(Color(red: 0.949, green: 0.729, blue: 0.216))
                )
        }
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

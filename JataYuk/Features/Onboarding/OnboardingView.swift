
//  OnboardingView.swift
//  JataYuk

//  Created by Stanley Pratama Teguh on 29/07/26.


import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: Store<RootState, RootAction>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                customColors.appCream.ignoresSafeArea()
                
                Image("VolcanoBackground")
                    .resizable()
                    .scaleEffect(1.20)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height * 0.85
                    )
                    .frame(
                        maxHeight: .infinity,
                        alignment: .bottom
                    )
                
                VStack(spacing: 80) {
                    Image("Title")
                        .frame(alignment: .center
                        ).offset(x: -10, y: -85)
                        .scaleEffect(1.1)
                    
                    exploreButton
                        .offset(y: -10)
                }
                .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.52)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private var exploreButton: some View {
        Button {
            store.send(.playButtonSound)
            store.send(.onboarding(.letsExploreTapped))
        } label: {
            Text("Let's Explore!")
                .font(.custom("Fredoka-Medium", size: 20))
                .foregroundStyle(.white)
                .frame(width: 320)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(customColors.appYellow, in: Capsule())
                .glassEffect(.regular.interactive())
                .shadow(
                    color: .black.opacity(0.25),
                    radius: 4, x: 0, y: 4
                    
                )
                
        }
    }
}

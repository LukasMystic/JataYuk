//
//  EndView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI

struct EndView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        GeometryReader { geometry in
            ZStack {

                // MARK: - Background
                Color(red: 0.949, green: 0.945, blue: 0.902)
                    .ignoresSafeArea()
                
                // Image("VolcanoBckg")
                //     .resizable()
                //     .scaledToFill()
                //     .ignoresSafeArea()

                VStack(spacing: 28) {
                    
                    // MARK: - Logo?

                    Text("Experiment Complete!")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)

                    // MARK: - Reaction Message
                    VStack(spacing: 10) {
                        Text("Nice reaction! 🌋")
                            .font(.custom("Fredoka_Bold", size: 24))
                        Text("What do you think will happen if we change the hydrogen peroxide concentration?")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 500)
//                    .background(
//                        RoundedRectangle(
//                            cornerRadius: 24,
//                            style: .continuous
//                        )
//                        .fill(.white.opacity(0.92))
//                    )

                    // MARK: - Buttons
                    VStack(spacing: 14) {

                        Button {
                            store.send(.navigate(to: .onboarding))
                        } label: {
                            Text("Experiment Again")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 382)
                                .padding(.vertical, 15)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.949, green: 0.729, blue: 0.216))
                                )
                        }

                        Button {
                            // Add achievements action later
                        } label: {
                            Text("See Achievements")
                                .font(
                                    .system(
                                        size: 19,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(Color(red: 0.949, green: 0.729, blue: 0.216))
                                .frame(width: 382)
                                .padding(.vertical, 15)
                                .background(
                                    Capsule()
                                        .stroke(Color(red: 0.949, green: 0.729, blue: 0.216), lineWidth: 3))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .position(
                    x: geometry.size.width * 0.5,
                    y: geometry.size.height * 0.5
                )
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    EndView(
        store: Store(
            initialState: RootState(),
            reducer: rootReducer,
            environment: RootEnvironment()
        )
    )
}

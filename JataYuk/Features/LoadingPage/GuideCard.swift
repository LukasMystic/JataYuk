//
//  GuideCard.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import SwiftUI

// MARK: - GuideCard (data model)
//
enum GuideData {
    static let guides: [GuideCard] = [
        GuideCard(
            title: "AR Guide Set Up",
            subtitle: "Quick Tip",
            description: "Hold your device in portrait mode when completing the AR experiments!"
        ),
        GuideCard(
            title: "AR Guide Set Up",
            subtitle: "Turn on Sound!",
            description: "To hear the audio instructions for each AR experiment, please check you have silent mode turned off and increase your device volume to your liking!"
        ),
        GuideCard(
            title: "AR Guide Set Up",
            subtitle: "Quick Tip",
            description: "Hold your iPad in horizontally when conducting the experiment!"
        )
    ]
}


struct GuideCard: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let description: String
}

// MARK: - GuideCardView (reusable component)
//
struct GuideCardView: View {
    let guide: GuideCard

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(guide.title)
                    .font(.custom("Fredoka-Bold", size: 64))
                    .foregroundStyle(customColors.appYellow)
                    .padding(.horizontal, 10)
                
                if !guide.subtitle.isEmpty {
                    Text(guide.subtitle)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                }
                if !guide.description.isEmpty {
                    Text(guide.description)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 600, alignment: .leading)
                        .padding(.horizontal, 10)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // reserve room so the mascot never overlaps short text
                Color.clear.frame(height: 200)
            }
            .padding(.trailing, 90)

            // Mascot
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 270, height: 300)
                .rotationEffect(.degrees(5))
                .shadow(color: .white.opacity(0.9), radius: 10, x: 6, y: 9
                )
                .offset(x: 10, y: 30)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
        }
        .padding(24)
        .frame(maxWidth: 888, alignment: .leading)
        .background(Color(red: 27 / 255,green: 27 / 255, blue: 27 / 255).opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous)) //darkCard
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .id(guide.id) // forces a clean transition when the card changes
    }
}

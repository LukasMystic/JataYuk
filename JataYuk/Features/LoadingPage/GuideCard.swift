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
            //mascotImage: "duar_mascot_portrait_tip"
        ),
        GuideCard(
            title: "AR Guide Set Up",
            subtitle: "Turn on Sound!",
            description: "To hear the audio instructions for each AR experiment, please check you have silent mode turned off and increase your device volume to your liking!"
            //mascotImage: "duar_mascot_sound_tip"
        ),
        GuideCard(
            title: "AR Guide Set Up",
            subtitle: "Quick Tip",
            description: "Hold your iPad in horizontally when conducting the experiment!"
            //mascotImage: "duar_mascot_horizontal_tip"
        )
    ]
}


struct GuideCard: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let subtitle: String
    let description: String
    //let mascotImage: String - MASCOT
}

// MARK: - GuideCardView (reusable component)
//
struct GuideCardView: View {
    let guide: GuideCard

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(guide.title)
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.949, green: 0.729, blue: 0.216)) //yellow

                if !guide.subtitle.isEmpty {
                    Text(guide.subtitle)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
                if !guide.description.isEmpty {
                    Text(guide.description)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // reserve room so the mascot never overlaps short text
                Color.clear.frame(height: 200)
            }
            .padding(.trailing, 90)

            //DuARMascotView(size: 76) - MASCOT
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

#Preview {
    GuideCardView(guide: GuideData.guides[0])
//        .padding()
//        .background(Color(red: 0.965, green: 0.945, blue: 0.902)) //cream
}

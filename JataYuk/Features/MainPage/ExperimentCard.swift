//
//  ExperimentCard.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import SwiftUI

struct ExperimentCard: Identifiable, Equatable {
    let id: UUID = UUID()
    let category: String
    let title: String
    let mascotImageName: String
}

enum ExperimentData {
    static let experiments: [ExperimentCard] = [
        ExperimentCard(
            category: "Chemistry",
            title: "Elephant's Toothpaste",
            mascotImageName: "Mascot"
        ),
        ExperimentCard(
            category: "Physics",
            title: "Pendulum Impact",
            mascotImageName: "Mascot"
        ),
        ExperimentCard(
            category: "Chemistry",
            title: "Redox Reaction",
            mascotImageName: "Mascot"
        ),
        ExperimentCard(
            category: "Chemistry",
            title: "Crystal Growth",
            mascotImageName: "Mascot"
        ),
        ExperimentCard(
            category: "Physics",
            title: "Solar System",
            mascotImageName: "Mascot"
        )
    ]
}

struct ExperimentCardView: View {

    let experiment: ExperimentCard
    let onPlayTapped: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // Mascot
            Image(experiment.mascotImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 270, height: 340)
                .rotationEffect(.degrees(-5))
                .shadow(color: .white.opacity(0.9),radius: 10,x: 6,y: 9
                )
                .offset(x: 150, y: 30)

            // Text
            VStack(alignment: .leading, spacing: 8) {
                Text(experiment.category.uppercased())
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                

                Text(experiment.title)
                    .font(.custom("Fredoka-Bold", size: 64))
                    .foregroundStyle(customColors.appYellow)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding(.horizontal, 30)
            .padding(.top, 20)

            playButton
                .padding(16)
        }
        .frame(width: 452, height: 514)
        .background(
            customColors.appBlack.opacity(0.9),
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private var playButton: some View {
        Button(action: onPlayTapped) {
            Image(systemName: "play.circle")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}


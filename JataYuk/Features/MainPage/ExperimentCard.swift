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
    //let mascotImageName: String
}

enum ExperimentData {
    static let experiments: [ExperimentCard] = [
        ExperimentCard(
            category: "Chemistry",
            title: "Elephant's Toothpaste",
            //mascotImageName: "duar_experiment_elephant_toothpaste"
        ),
        ExperimentCard(
            category: "Physics",
            title: "Pendulum Impact",
            //mascotImageName: "duar_experiment_pendulum_impact"
        ),
        ExperimentCard(
            category: "Chemistry",
            title: "Redox Reaction",
            //mascotImageName: "duar_experiment_redox_reaction"
        ),
        ExperimentCard(
            category: "Chemistry",
            title: "Crystal Growth",
            //mascotImageName: "duar_experiment_crystal_growth"
        )
    ]
}

struct ExperimentCardView: View {

    let experiment: ExperimentCard
    let onPlayTapped: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(experiment.category.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(experiment.title)
                    .font(
                        .system(
                            size: 24,
                            weight: .heavy,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Color(
                        red: 0.949,
                        green: 0.729,
                        blue: 0.216)) //yellow
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Spacer(minLength: 0)

                HStack {
                    Spacer()

                    // Mascot will go here later
                    // DuARMascotView(size: 96)
                }
            }
            .padding(20)

            playButton
                .padding(16)
        }
        .frame(width: 260, height: 320)
        .background(
            Color(red: 37 / 255, green: 57 / 255, blue: 66 / 255),
            in: RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private var playButton: some View {
        Button(action: onPlayTapped) {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
        }
        .accessibilityLabel("Play \(experiment.title)")
    }
}

#Preview {
    ExperimentCardView(
        experiment: ExperimentData.experiments[0],
        onPlayTapped: {}
    )
    //.padding()
    //.background(DuARColor.cream)
}

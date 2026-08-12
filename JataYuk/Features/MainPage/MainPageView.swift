//
//  MainPageView.swift
//  JataYuk
//
//  Created by Miranda Khairunnisa on 12/08/26.
//

import SwiftUI

struct MainPageView: View {
    @ObservedObject var store: Store<MainPageState, MainPageAction>

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 28) {
                header
                experimentsRow
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Spacer()

            DuARSegmentedControl(
                tabs: MainPageTab.allCases,
                selection: Binding(
                    get: { store.state.selectedTab },
                    set: { store.send(.tabSelected($0)) }
                )
            )

            Spacer()

            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.black.opacity(0.8))
            }
            .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder
    private var experimentsRow: some View {
        switch store.state.selectedTab {
        case .experiments:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(store.state.experiments) { experiment in
                        ExperimentCardView(experiment: experiment) {
                            store.send(.playButtonTapped(experiment))
                        }
                    }
                }
                .padding(.vertical, 8)
            }

        case .achievements:
            achievementsPlaceholder
        }
    }

    private var achievementsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "rosette")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Achievements coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Segmented Control

struct DuARSegmentedControl: View {
    let tabs: [MainPageTab]
    @Binding var selection: MainPageTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Text(tab.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule().fill(Color.black.opacity(0.06))
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = tab
                        }
                    }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.04)))
    }
}

#Preview {
    MainPageView(
        store: Store(
            initialState: MainPageState(),
            reducer: MainPageReducer.reduce,
            environment: RootEnvironment()
        )
    )
}

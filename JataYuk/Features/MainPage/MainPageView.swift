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
            .glassEffect()

            Spacer()

            Button {
                store.send(.settingsButtonTapped)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title)
                    .foregroundStyle(.black)            }
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
        VStack(spacing: 50) {
            Image(systemName: "medal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Achievements coming soon")
                .font(.system(size: 25))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 100)
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
                    //.font(.custom("Fredoka-Bold", size: 15))
                    .font(.system(size: 20,weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        selection == tab ? .black : .primary
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background {
                        if selection == tab {
                            Capsule().fill(Color(red: 0.949, green: 0.729, blue: 0.216))}}
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = tab
                        }
                    }
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

#Preview (traits: .landscapeLeft) {
    MainPageView(
        store: Store(
            initialState: MainPageState(),
            reducer: MainPageReducer.reduce,
            environment: RootEnvironment()
        )
    )
}

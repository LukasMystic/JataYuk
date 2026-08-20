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
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                customColors.appCream
                    .ignoresSafeArea()

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

                VStack(alignment: .leading, spacing: 28) {
                    header
                    experimentsRow
                    Spacer(minLength: 0)
                }
                .padding(.top, geometry.size.height * 0.03)
                .padding(.horizontal, geometry.size.width * 0.04)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var header: some View {
        HStack {
            Image("Title")
                .resizable()
                .frame(width: 197)
                .frame(height: 83)

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
            }
            .disabled(true)
        }
    }

    private var experimentsRow: some View {
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
                    .font(.custom("Fredoka-Medium", size: 20))
                    .foregroundStyle(
                        selection == tab ? .black : .primary
                    )
                    .frame(width: 430, height: 50)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(customColors.appYellow)
                        }
                    }
                    .contentShape(Capsule())
                    }
            }
        }
    }


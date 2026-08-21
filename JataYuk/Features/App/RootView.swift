//
//  RootView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        ZStack {
            routeView

            if store.state.isItemInfoVisible, let item = store.state.activeInfoItem {
                ItemInfoView(store: store, item: item)
            }
        }
        .onAppear {
            store.send(.loadingPage(.onAppear))
            store.send(.navigate(to: store.state.currentRoute))
        }
    }

    @ViewBuilder
    private var routeView: some View {
        switch store.state.currentRoute {
        case .loading:
            LoadingPageView(store: store)
        case .onboarding:
            OnboardingView(store: store)
        case .main:
            MainPageView(store: store)
        case .ar:
            ARExperimentView(store: store)
        case .end:
            EndView(store: store)
        }
    }
}

//private struct ItemInfoOverlayPlaceholder: View {
//    @ObservedObject var store: Store<RootState, RootAction>
//    let item: BeakerType
//
//    var body: some View {
//        Color.black.opacity(0.6).ignoresSafeArea()
//        VStack(spacing: 16) {
//            Text("Info: \(String(describing: item))").font(.title).foregroundColor(.white)
//            Button("Close") { store.send(.overlay(.hideItemInfo)) }
//                .foregroundColor(.white)
//        }
//    }
//} button udah ada di ARExperimentView file with inHandInfoButton

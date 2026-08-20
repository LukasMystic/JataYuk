//
//  ContentView.swift
//  JataYuk
//
//  Created by Stanley Pratama Teguh on 29/07/26.

import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store(
        initialState: RootState(),
        reducer: rootReducer,
        environment: RootEnvironment()
    )

    var body: some View {
        if ShaderPreviewGate.isEnabled {
            ShaderPreviewView()
        } else {
            RootView(store: store)
        }
    }
}

#Preview { ContentView() }

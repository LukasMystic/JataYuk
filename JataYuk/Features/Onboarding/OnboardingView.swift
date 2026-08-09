import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("JataYuk")
                .font(.largeTitle.bold())
            Text("Elephant Toothpaste AR")
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
            Button("Start Experiment") {
                if !store.state.hasSeenInstructions {
                    store.send(.overlay(.showInstruction))
                    store.send(.overlay(.markInstructionsSeen))
                }
                store.send(.navigate(to: .ar))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}

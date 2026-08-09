import SwiftUI

struct EndView: View {
    @ObservedObject var store: Store<RootState, RootAction>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Experiment Complete!")
                .font(.largeTitle.bold())
            Text("Great job, scientist!")
                .font(.title2)
                .foregroundColor(.secondary)
            Spacer()
            Button("Try Again") {
                store.send(.navigate(to: .onboarding))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}

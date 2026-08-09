import Foundation

enum AppRoute: Equatable {
    case onboarding
    case ar
    case end
}

struct RootState: Equatable {
    var currentRoute: AppRoute = .onboarding
    var ar: ARState = ARState()
    var experiment: ExperimentState = .initial()
    var hasSeenInstructions: Bool = false
    var isInstructionVisible: Bool = false
    var isItemInfoVisible: Bool = false
    var activeInfoItem: BeakerType? = nil
}

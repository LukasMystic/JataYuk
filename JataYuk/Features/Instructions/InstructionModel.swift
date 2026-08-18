enum InstructionStepKey: Equatable {

    // MARK: AR Placement
    case placeVolcano
    case placeSideA
    case placeSideB

    // MARK: Neutral / side intros
    case introSolutions
    case sideAIntro
    case sideBIntro
    case moveCloserToBench

    // MARK: Ingredient "near" (first encounter, not yet poured)
    case h2o2Near
    case soapNear
    case foodColoringNear
    case yeastNear
    case waterNear

    // MARK: Holding / pouring — shared
    case bringToBeaker
    case pourIngredient
    case offerMore

    // MARK: Beaker
    case readyToMixSideA
    case readyToMixSideB
    case shakeToMix
    case maxPoursReached //added
    case sideComplete

    // MARK: AR Volcano
    case noSolutionsYet
    case interactVolcano
    case reacting
    case reactionDone
}

enum InstructionCopy {

    static let steps: [InstructionStep] = [

        // MARK: AR Placement

        .init(key: .placeVolcano, stepNumber: 0, context: .arPlacement,
              title: "Place the volcano",
              description: "Place the volcano in your space.",
              animation: nil),

        .init(key: .placeSideA, stepNumber: 1, context: .arPlacement,
              title: "Place Side A",
              description: "Now place the bench for Side A.",
              animation: nil),

        .init(key: .placeSideB, stepNumber: 2, context: .arPlacement,
              title: "Place Side B",
              description: "Now place the bench for Side B.",
              animation: nil),

        .init(key: .introSolutions, stepNumber: 3, context: .arPlacement,
              title: "Two solutions",
              description: "Ready to start? We first need to make two solutions. One for Hydrogen Peroxide and the other for Yeast.\n\nLet's start with one side of the table.",
              animation: nil),

        .init(key: .moveCloserToBench, stepNumber: 4, context: .arPlacement,
              title: "Move closer",
              description: "Move closer to the bench.",
              animation: nil),

        // MARK: Side A

        .init(key: .sideAIntro, stepNumber: 5, context: .arSideA,
              title: "Hydrogen peroxide solution",
              description: "First, let's make the hydrogen peroxide solution with dish soap and some food coloring.",
              animation: nil),

        .init(key: .h2o2Near, stepNumber: 6, context: .arSideA,
              title: "Find the hydrogen peroxide",
              description: "Hydrogen peroxide is the main ingredient. You can choose one from the three different concentrations available.\n\nTap the screen to pick it up.",
              animation: nil),

        .init(key: .soapNear, stepNumber: 7, context: .arSideA,
              title: "Add the dish soap",
              description: "Now let's add the dish soap. These will create the foam.\n\nTap the screen to pick it up.",
              animation: nil),

        .init(key: .foodColoringNear, stepNumber: 8, context: .arSideA,
              title: "Add food coloring",
              description: "Let's add some color using these food coloring! Choose your favorite color.",
              animation: nil),

        .init(key: .readyToMixSideA, stepNumber: 9, context: .arSideA,
              title: "Time to mix",
              description: "Awesome! The hydrogen peroxide solution is now ready to be mixed.\n\nTap on the screen to start mixing.",
              animation: nil),

        // MARK: Side B

        .init(key: .sideBIntro, stepNumber: 10, context: .arSideB,
              title: "Yeast solution",
              description: "Here, we're going to mix yeast with warm water.",
              animation: nil),

        .init(key: .yeastNear, stepNumber: 11, context: .arSideB,
              title: "Pick up the yeast",
              description: "Let's add the yeast itself!\n\nTap the screen to pick it up.",
              animation: nil),

        .init(key: .waterNear, stepNumber: 12, context: .arSideB,
              title: "Add water",
              description: "To activate the yeast, we need to add some water.\n\nYou can adjust the temperature.",
              animation: nil),

        .init(key: .readyToMixSideB, stepNumber: 13, context: .arSideB,
              title: "Time to mix",
              description: "Great job! Time to mix!\n\nTap on the screen to start mixing.",
              animation: nil),

        // MARK: Shared holding / pouring

        .init(key: .bringToBeaker, stepNumber: 14, context: .arSideA,
              title: "Bring it over",
              description: "Bring it over to the beaker.",
              animation: nil),

        .init(key: .pourIngredient, stepNumber: 15, context: .arSideA,
              title: "Pour",
              description: "Tilt your iPad to pour.",
              animation: nil),

        .init(key: .offerMore, stepNumber: 16, context: .arSideA,
              title: "Add more?",
              description: "Want to add more, or move to the next step?",
              animation: nil),

        .init(key: .shakeToMix, stepNumber: 17, context: .arSideA,
              title: "Shake",
              description: "Now shake your iPad gently to mix everything together!",
              animation: nil),

        .init(key: .sideComplete, stepNumber: 18, context: .arSideA,
              title: "Side complete",
              description: "Great job! Let's move over to the other side to make the next solution.",
              animation: nil),

        // MARK: AR Volcano
        .init(key: .noSolutionsYet, stepNumber: 19, context: .arVolcano,
              title: "Combine the solutions",
              description: "Start on one of the benches!",
              animation: nil),
        
        .init(key: .interactVolcano, stepNumber: 20, context: .arVolcano,
              title: "Combine the solutions",
              description: "Now that we have both solutions, are you ready to combine them and see what happens? Let's move back to our volcano! \n\nTap Interact to pour both solutions in!",
              animation: nil),

        .init(key: .reacting, stepNumber: 21, context: .arVolcano,
              title: "Watch closely!",
              description: "Watch closely and see what happens!",
              animation: nil),

        .init(key: .reactionDone, stepNumber: 22, context: .arVolcano,
              title: "Reaction complete",
              description: "Wow! Look at all that foam! But... how did that happen?",
              animation: nil)
    ]

    static func step(for key: InstructionStepKey) -> InstructionStep {
        steps.first { $0.key == key }!
    }
}

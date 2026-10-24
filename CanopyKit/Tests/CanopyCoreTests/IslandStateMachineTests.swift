import Testing
@testable import CanopyCore

struct IslandStateMachineTests {
    @Test func startsClosed() {
        #expect(IslandStateMachine().phase == .closed)
    }

    @Test func hoverExpandsAndLeavingCloses() {
        var machine = IslandStateMachine()
        machine.handle(.pointerEntered)
        #expect(machine.phase == .expanded)
        machine.handle(.pointerExited)
        #expect(machine.phase == .closed)
    }

    @Test func leavingReturnsToCompactWhenAnActivityIsRunning() {
        var machine = IslandStateMachine()
        machine.handle(.activitiesChanged(hasActivity: true))
        #expect(machine.phase == .compact)
        machine.handle(.pointerEntered)
        machine.handle(.pointerExited)
        #expect(machine.phase == .compact)
    }

    @Test func clickKeepsItOpenUntilDismissed() {
        var machine = IslandStateMachine()
        machine.handle(.pointerEntered)
        machine.handle(.clicked)
        machine.handle(.pointerExited)
        #expect(machine.phase == .expanded)
        machine.handle(.dismissed)
        #expect(machine.phase == .closed)
        #expect(!machine.isPinned)
    }

    @Test func newActivityDoesNotCollapseAnOpenIsland() {
        var machine = IslandStateMachine()
        machine.handle(.pointerEntered)
        machine.handle(.activitiesChanged(hasActivity: true))
        #expect(machine.phase == .expanded)
    }

    @Test func endingTheLastActivityCloses() {
        var machine = IslandStateMachine()
        machine.handle(.activitiesChanged(hasActivity: true))
        machine.handle(.activitiesChanged(hasActivity: false))
        #expect(machine.phase == .closed)
    }

    @Test func remembersWhetherTheLastChangeGrewOrShrank() {
        var machine = IslandStateMachine()
        machine.handle(.pointerEntered)
        #expect(machine.lastChangeGrew)
        machine.handle(.pointerExited)
        #expect(!machine.lastChangeGrew)
        // Um evento que não muda o estado mantém a direção anterior.
        machine.handle(.pointerExited)
        #expect(!machine.lastChangeGrew)
    }
}

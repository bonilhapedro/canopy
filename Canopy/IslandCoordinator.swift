import CanopyCore
import Foundation
import Observation

/// Guarda as atividades em andamento e decide o que a ilha mostra.
@MainActor
@Observable
final class IslandCoordinator {
    private(set) var machine = IslandStateMachine()
    private(set) var queue = ActivityQueue()
    private var activities: [String: any IslandActivity] = [:]
    @ObservationIgnored private var collapseTask: Task<Void, Never>?

    var geometry = NotchGeometry(rect: CGRect(x: 0, y: 0, width: NotchGeometry.fallbackWidth, height: 24), hasNotch: false)

    var phase: IslandPhase { machine.phase }
    var layout: IslandLayout { IslandLayout(notch: geometry.rect.size) }

    var primary: (any IslandActivity)? {
        queue.primary.flatMap { activities[$0.id] }
    }

    /// As atividades que estão atrás da principal.
    var secondary: [any IslandActivity] {
        queue.ordered.dropFirst().compactMap { activities[$0.id] }
    }

    func start(_ activity: any IslandActivity) {
        activities[activity.id] = activity
        queue.upsert(ActivityEntry(id: activity.id, priority: activity.priority, startedAt: .now))
        machine.handle(.activitiesChanged(hasActivity: true))
    }

    func end(id: String) {
        activities[id] = nil
        queue.remove(id: id)
        machine.handle(.activitiesChanged(hasActivity: !queue.isEmpty))
    }

    func pointer(inside: Bool) {
        collapseTask?.cancel()
        if inside {
            machine.handle(.pointerEntered)
        } else {
            // Uma pequena espera evita que a ilha pisque quando o mouse passa raspando pela borda.
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                self?.machine.handle(.pointerExited)
            }
        }
    }

    func click() {
        machine.handle(.clicked)
    }

    func dismiss() {
        machine.handle(.dismissed)
    }

    var showsDemoActivity: Bool {
        get { queue.contains(id: DemoActivity.activityID) }
        set { newValue ? start(DemoActivity()) : end(id: DemoActivity.activityID) }
    }
}

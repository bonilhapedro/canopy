import CanopyCore
import CoreGraphics
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
    @ObservationIgnored private var flashTasks: [String: Task<Void, Never>] = [:]

    @ObservationIgnored private var swipe = SwipeTracker()
    /// Avisa quando a ilha muda de tamanho, para quem só precisa trabalhar com ela aberta.
    @ObservationIgnored var onPhaseChange: ((IslandPhase) -> Void)?

    var geometry = NotchGeometry(rect: CGRect(x: 0, y: 0, width: NotchGeometry.fallbackWidth, height: 24), hasNotch: false)
    /// Ajuste fino do tamanho da ilha fechada, vindo dos Ajustes.
    var closedAdjustment = CGSize.zero
    var showsWeather = true
    var showsTray = false

    /// A área da bandeja sob um arquivo sendo arrastado até a ilha, ou nil sem arraste.
    private(set) var dropZone: ShelfDropZone?
    /// A bandeja tem mais arquivos do que cabem e rola para os lados: o arrastar de dois dedos
    /// fica com ela em vez de trocar de página.
    @ObservationIgnored var trayScrolls = false

    /// A página escolhida na ilha aberta.
    private(set) var page = IslandPage.home
    /// Para que lado a última troca de página andou: +1 para a direita, -1 para a esquerda.
    private(set) var pageStep = 1

    var phase: IslandPhase { machine.phase }
    var layout: IslandLayout {
        IslandLayout(notch: geometry.rect.size, hasNotch: geometry.hasNotch, closedAdjustment: closedAdjustment)
    }
    var lastChangeGrew: Bool { machine.lastChangeGrew }

    var pages: [IslandPage] {
        IslandPage.available(hasActivity: primary != nil, showsWeather: showsWeather, showsTray: showsTray)
    }

    /// A página que aparece de fato: se a escolhida sumiu, a primeira disponível.
    var currentPage: IslandPage {
        let pages = pages
        return pages.contains(page) ? page : pages.first ?? .home
    }

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
        // Um alerta com a ilha aberta em outra página precisa aparecer.
        if activity.priority >= .alert, phase == .expanded, page != .now {
            show(.now)
        }
        handle(.activitiesChanged(hasActivity: true))
    }

    func end(id: String) {
        activities[id] = nil
        queue.remove(id: id)
        handle(.activitiesChanged(hasActivity: !queue.isEmpty))
    }

    func isActive(id: String) -> Bool {
        queue.contains(id: id)
    }

    /// Mostra uma atividade por um tempo curto, como o HUD de volume.
    /// Repetir antes do fim troca o conteúdo e reinicia o prazo, sem reordenar a fila.
    func flash(_ activity: any IslandActivity, for duration: Duration) {
        let id = activity.id
        flashTasks[id]?.cancel()
        if queue.contains(id: id) {
            activities[id] = activity
        } else {
            start(activity)
        }
        flashTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.flashTasks[id] = nil
            self?.end(id: id)
        }
    }

    func pointer(inside: Bool) {
        collapseTask?.cancel()
        if inside {
            guard Preferences.expandOnHover else { return }
            handle(.pointerEntered)
        } else {
            // Uma pequena espera evita que a ilha pisque quando o mouse passa raspando pela borda.
            scheduleCollapse(after: .milliseconds(200))
        }
    }

    private func scheduleCollapse(after delay: Duration) {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.handle(.pointerExited)
        }
    }

    func click() {
        handle(.clicked)
    }

    func dismiss() {
        handle(.dismissed)
    }

    // MARK: - Arrastar arquivos

    /// Um arquivo chegou ao notch: a ilha abre na bandeja.
    func dropEntered() {
        collapseTask?.cancel()
        handle(.pointerEntered)
        select(.tray)
    }

    func dropMoved(to zone: ShelfDropZone) {
        if dropZone != zone { dropZone = zone }
    }

    /// O arquivo saiu da ilha ou foi solto. Depois de soltar, a ilha espera um pouco
    /// para mostrar o que entrou na bandeja.
    func dropExited(dropped: Bool) {
        if dropZone != nil { dropZone = nil }
        scheduleCollapse(after: dropped ? .seconds(1.6) : .milliseconds(200))
    }

    // MARK: - Páginas

    func select(_ newPage: IslandPage) {
        guard newPage != currentPage, pages.contains(newPage) else { return }
        let pages = pages
        let from = pages.firstIndex(of: currentPage) ?? 0
        let to = pages.firstIndex(of: newPage) ?? 0
        pageStep = to >= from ? 1 : -1
        page = newPage
    }

    /// Arrastar de dois dedos no trackpad troca de página com a ilha aberta.
    /// - Parameter fingerDeltaX: quanto os dedos andaram; positivo é para a direita.
    func scroll(fingerDeltaX: Double, phase scrollPhase: SwipeTracker.Phase) {
        guard phase == .expanded, !(currentPage == .tray && trayScrolls) else { return }
        guard let step = swipe.handle(fingerDeltaX: fingerDeltaX, phase: scrollPhase),
              let target = currentPage.neighbor(step, in: pages)
        else { return }
        select(target)
    }

    private func show(_ newPage: IslandPage) {
        pageStep = -1
        page = newPage
    }

    /// Passa o evento para a máquina de estados e, quando a ilha abre, volta para a primeira página.
    private func handle(_ event: IslandEvent) {
        var next = machine
        next.handle(event)
        // Sem mudança, nada é escrito: escrever avisaria todas as views da ilha à toa,
        // e isso acontece a cada clique fora dela ou a cada aviso de volume.
        guard next != machine else { return }
        let previous = machine.phase
        machine = next
        guard phase != previous else { return }
        if phase == .expanded {
            let first = pages.first ?? .home
            if page != first { page = first }
            if pageStep != 1 { pageStep = 1 }
        }
        onPhaseChange?(phase)
    }

    /// Guardado à parte para o menu da barra não depender da fila inteira.
    var showsDemoActivity = false {
        didSet {
            guard showsDemoActivity != oldValue else { return }
            showsDemoActivity ? start(DemoActivity()) : end(id: DemoActivity.activityID)
        }
    }
}

import CanopyCore
import SwiftUI

/// Uma coisa em andamento que pode ocupar o notch, com as mesmas regiões do ActivityKit do iOS.
@MainActor
protocol IslandActivity: AnyObject {
    var id: String { get }
    var priority: ActivityPriority { get }
    /// À esquerda do notch, no estado compacto.
    var compactLeading: AnyView { get }
    /// À direita do notch, no estado compacto.
    var compactTrailing: AnyView { get }
    /// Ícone pequeno, usado quando outra atividade está na frente.
    var minimal: AnyView { get }
    /// Conteúdo do painel aberto.
    var expanded: AnyView { get }
    /// Cor que tinge o brilho em volta da ilha aberta.
    var accent: Color? { get }
    /// Fundo atrás do conteúdo da ilha aberta, como a capa da música desfocada.
    var backdrop: AnyView? { get }
}

@MainActor
extension IslandActivity {
    var accent: Color? { nil }
    var backdrop: AnyView? { nil }
}

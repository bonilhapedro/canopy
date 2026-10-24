import CanopyCore
import SwiftUI

struct IslandView: View {
    @Environment(IslandCoordinator.self) private var coordinator

    var body: some View {
        let phase = coordinator.phase
        let size = coordinator.layout.size(for: phase)
        let radius: CGFloat = phase == .expanded ? 22 : 10
        let shape = UnevenRoundedRectangle(
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            style: .continuous
        )

        content(for: phase)
            .frame(width: size.width, height: size.height)
            .background(.black)
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: .black.opacity(phase == .expanded ? 0.35 : 0), radius: 12, y: 4)
            .onHover { coordinator.pointer(inside: $0) }
            .onTapGesture { coordinator.click() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: size)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(for phase: IslandPhase) -> some View {
        switch phase {
        case .closed:
            Color.clear
        case .compact:
            compactContent
        case .expanded:
            expandedContent
        }
    }

    private var compactContent: some View {
        HStack(spacing: 0) {
            coordinator.primary?.compactLeading
            Spacer(minLength: coordinator.layout.notch.width)
            coordinator.primary?.compactTrailing
        }
        .padding(.horizontal, 14)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let primary = coordinator.primary {
                primary.expanded
            } else {
                IdleView()
            }
            if !coordinator.secondary.isEmpty {
                HStack(spacing: 8) {
                    ForEach(coordinator.secondary, id: \.id) { $0.minimal }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, coordinator.layout.notch.height + 8)
        .padding([.horizontal, .bottom], 20)
    }
}

/// O que aparece ao abrir a ilha sem nenhuma atividade: hora e data.
private struct IdleView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        }
    }
}

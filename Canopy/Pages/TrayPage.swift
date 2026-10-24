import AppKit
import CanopyCore
import SwiftUI

/// A bandeja de arquivos na ilha aberta. Arraste um arquivo para fora para soltar em outro app;
/// clique duas vezes para abrir; clique com o botão direito para mais opções.
struct TrayPage: View {
    @Environment(IslandCoordinator.self) private var coordinator
    @Environment(FileTray.self) private var tray

    /// Quantos arquivos cabem lado a lado antes de a fileira rolar.
    static let visibleTiles = 5

    var body: some View {
        Group {
            if let zone = coordinator.dropZone {
                DropZones(zone: zone, islandWidth: coordinator.layout.size(for: .expanded).width)
                    .transition(.opacity.combined(with: .scale(0.96)))
            } else if tray.items.isEmpty && tray.pending == 0 {
                emptyState
                    .transition(.opacity)
            } else {
                shelf
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: coordinator.dropZone == nil)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { tray.validate() }
        .onChange(of: tray.items.count + tray.pending, initial: true) { _, count in
            coordinator.trayScrolls = count > Self.visibleTiles
        }
        .onDisappear { coordinator.trayScrolls = false }
    }

    private var emptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 66, height: 66)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Bandeja vazia")
                    .font(.system(size: 15, weight: .semibold))
                Text("Arraste arquivos até o notch para guardá-los aqui. Depois, solte em outro app ou mande por AirDrop.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .entrance(0)
    }

    private var shelf: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if tray.pending > 0 {
                        PendingTile(count: tray.pending)
                            .transition(.scale(0.8).combined(with: .opacity))
                    }
                    ForEach(tray.items) { item in
                        TrayTile(item: item)
                            .transition(.scale(0.8).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 2)
                .animation(.snappy(duration: 0.3), value: tray.items)
                .animation(.snappy(duration: 0.3), value: tray.pending > 0)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .entrance(0)

            actions
                .entrance(1)
        }
    }

    private var actions: some View {
        let urls = tray.items.map { tray.url(for: $0) }
        return VStack(spacing: 4) {
            // Pega todos de uma vez, como uma pilha.
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 32, height: 32)
                .overlay {
                    TrayDragSource(urls: urls, image: nil, onDragged: {
                        tray.draggedOut(tray.items.map(\.id))
                    })
                }
            Button {
                tray.airDrop(urls)
            } label: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            Button {
                tray.removeAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .buttonStyle(IslandButtonStyle(size: 32))
        .frame(maxHeight: .infinity)
    }
}

/// Um arquivo da bandeja: miniatura do Quick Look e nome.
private struct TrayTile: View {
    let item: ShelfItem
    @Environment(FileTray.self) private var tray
    @Environment(\.displayScale) private var displayScale
    @State private var isHovered = false

    var body: some View {
        let thumbnail = tray.thumbnails[item.id]
        VStack(spacing: 6) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .transition(.opacity)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
            }
            .frame(width: FileTray.thumbnailSize.width, height: FileTray.thumbnailSize.height)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .scaleEffect(isHovered ? 1.06 : 1)

            Text(item.name)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.white.opacity(isHovered ? 1 : 0.75))
                .padding(.horizontal, 4)
        }
        .frame(width: 76)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(isHovered ? 0.1 : 0))
        }
        .overlay {
            TrayDragSource(
                urls: [tray.url(for: item)],
                image: thumbnail,
                onOpen: { tray.open(item) },
                menu: { menu },
                onDragged: { tray.draggedOut([item.id]) }
            )
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button {
                    tray.remove(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(size: 20))
                .background(Circle().fill(.black.opacity(0.5)))
                .offset(x: -2, y: 2)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .task(id: item.id) {
            await tray.loadThumbnail(for: item, scale: displayScale)
        }
    }

    private var menu: NSMenu {
        let menu = NSMenu()
        menu.addItem(ActionMenuItem("Abrir", symbol: "arrow.up.forward.app") { tray.open(item) })
        menu.addItem(ActionMenuItem("Mostrar no Finder", symbol: "folder") { tray.reveal([item]) })
        menu.addItem(ActionMenuItem("Mandar por AirDrop", symbol: "dot.radiowaves.left.and.right") {
            tray.airDrop([tray.url(for: item)])
        })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Tirar da bandeja", symbol: "xmark") { tray.remove(item.id) })
        return menu
    }
}

/// Lugar de um arquivo que ainda está chegando, como uma foto vinda do Fotos.
private struct PendingTile: View {
    let count: Int

    var body: some View {
        VStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .frame(width: FileTray.thumbnailSize.width, height: FileTray.thumbnailSize.height)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(count == 1 ? "Chegando…" : "\(count) chegando…")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 76)
        .padding(.vertical, 8)
    }
}

/// As duas áreas enquanto um arquivo é arrastado até a ilha: guardar à esquerda, AirDrop à direita.
/// A divisão é a mesma de `ShelfDropLayout`, que decide onde o arquivo cai.
private struct DropZones: View {
    let zone: ShelfDropZone
    let islandWidth: CGFloat

    /// O espaço entre as áreas e a margem lateral do conteúdo da ilha.
    private let gap: CGFloat = 10
    private let margin: CGFloat = 22

    var body: some View {
        HStack(spacing: gap) {
            card(symbol: "tray.and.arrow.down.fill", title: "Guardar na bandeja", tint: .white, isActive: zone == .tray)
            card(symbol: "dot.radiowaves.left.and.right", title: "AirDrop", tint: .blue, isActive: zone == .airDrop)
                .frame(width: max(islandWidth * ShelfDropLayout.airDropFraction - margin - gap / 2, 0))
        }
        .animation(.snappy(duration: 0.25), value: zone)
    }

    private func card(symbol: String, title: String, tint: Color, isActive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isActive ? tint : .white.opacity(0.5))
                .symbolEffect(.bounce, value: isActive)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(isActive ? 1 : 0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(isActive ? .clear.tint(tint.opacity(0.22)) : .identity, in: shape)
        .overlay {
            shape
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(.white.opacity(isActive ? 0.7 : 0.22))
        }
        .scaleEffect(isActive ? 1.02 : 1)
    }
}

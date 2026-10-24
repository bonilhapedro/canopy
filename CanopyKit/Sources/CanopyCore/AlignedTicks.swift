import Foundation

/// Os instantes em que um valor mostrado na tela muda, para a tela só ser atualizada neles.
/// Uma contagem de "4:05" só muda no segundo cheio; redesenhar entre um e outro é trabalho jogado fora.
public enum AlignedTicks {
    /// O primeiro instante depois de `date` que cai em `anchor + k * interval`, para algum k inteiro.
    public static func next(after date: Date, anchor: Date, interval: TimeInterval) -> Date {
        guard interval > 0 else { return .distantFuture }
        let steps = (date.timeIntervalSince(anchor) / interval).rounded(.down) + 1
        return anchor.addingTimeInterval(steps * interval)
    }
}

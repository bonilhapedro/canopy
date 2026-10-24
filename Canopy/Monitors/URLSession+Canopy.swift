import Foundation

extension URLSession {
    /// Sem cache em disco nem na memória: o clima e as capas são pedidos poucas vezes
    /// e não vale guardar cópia de nada.
    static let canopy: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }()
}

import AppKit

@MainActor
enum AppleScriptRunner {
    /// Scripts fixos já compilados. Compilar custa mais do que rodar, e estes rodam a cada troca de faixa.
    private static var compiled: [String: NSAppleScript] = [:]

    /// Roda um script e devolve o resultado, ou nil se falhar ou a Automação for negada.
    /// - Parameter keepCompiled: guarda o script compilado para a próxima vez; só para textos fixos.
    @discardableResult
    static func run(_ source: String, keepCompiled: Bool = false) -> NSAppleEventDescriptor? {
        let script: NSAppleScript?
        if keepCompiled {
            script = compiled[source] ?? NSAppleScript(source: source)
            compiled[source] = script
        } else {
            script = NSAppleScript(source: source)
        }
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}

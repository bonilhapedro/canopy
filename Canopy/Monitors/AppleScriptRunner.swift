import AppKit

@MainActor
enum AppleScriptRunner {
    /// Roda um script e devolve o resultado, ou nil se falhar ou a Automação for negada.
    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}

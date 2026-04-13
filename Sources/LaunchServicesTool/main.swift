import CoreServices
import AppKit
import Foundation

enum CommandError: Error, CustomStringConvertible {
    case usage
    case missingValue(String)
    case launchServices(OSStatus)

    var description: String {
        switch self {
        case .usage:
            return "Usage: awdl-jit-ls <get-scheme|set-scheme|get-content|set-content> ..."
        case .missingValue(let value):
            return "Missing value: \(value)"
        case .launchServices(let status):
            return "LaunchServices error: \(status)"
        }
    }
}

func getScheme(_ scheme: String) {
    guard let url = URL(string: "\(scheme)://awdl-jit") else {
        return
    }
    if let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
       let bundleID = Bundle(url: appURL)?.bundleIdentifier {
        print(bundleID)
    }
}

func setScheme(_ scheme: String, bundleID: String) throws {
    let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bundleID as CFString)
    guard status == noErr else {
        throw CommandError.launchServices(status)
    }
}

func getContent(_ uti: String) {
    let result = LSCopyDefaultRoleHandlerForContentType(uti as CFString, .viewer)?.takeRetainedValue() as String?
    if let result {
        print(result)
    }
}

func setContent(_ uti: String, bundleID: String) throws {
    let status = LSSetDefaultRoleHandlerForContentType(uti as CFString, .viewer, bundleID as CFString)
    guard status == noErr else {
        throw CommandError.launchServices(status)
    }
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        throw CommandError.usage
    }

    switch command {
    case "get-scheme":
        guard args.count >= 2 else { throw CommandError.missingValue("scheme") }
        getScheme(args[1])
    case "set-scheme":
        guard args.count >= 3 else { throw CommandError.missingValue("scheme and bundle id") }
        try setScheme(args[1], bundleID: args[2])
    case "get-content":
        guard args.count >= 2 else { throw CommandError.missingValue("content type") }
        getContent(args[1])
    case "set-content":
        guard args.count >= 3 else { throw CommandError.missingValue("content type and bundle id") }
        try setContent(args[1], bundleID: args[2])
    default:
        throw CommandError.usage
    }
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}

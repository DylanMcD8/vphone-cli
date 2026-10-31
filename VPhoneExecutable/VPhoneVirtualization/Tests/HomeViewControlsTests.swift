import Foundation

@MainActor private final class Guest {
    var online = true
    var settings: [String: [String: Any]] = [:]
    var flags: [String: Any] = ["Unrelated": ["Enabled": true]]
    var uploads = 0
    var mutations = 0
    var failInterval = false
    var failBackup = false
    var failWifi = false
    var flagExists = true
    var shellRefreshes = 0
    var wifi = false
    var location = false
    var personal = false
    let profile = "11111111-1111-1111-1111-111111111111"
    let originalFace = "22222222-2222-2222-2222-222222222222"
    var selected = "22222222-2222-2222-2222-222222222222"
    var faces: [(String, String, String)] = [("com.apple.Home.HomeFace", "default-color-1", "22222222-2222-2222-2222-222222222222")]
    var creates = 0
    func call(_ method: String, _ p: [String: Any]) throws -> [String: Any] {
        func key() -> String { (p["domain"] as? String ?? "") + "/" + (p["key"] as? String ?? "") }
        switch method {
        case "settings.get": return settings[key()] ?? ["exists": false, "value": NSNull(), "type": "null"]
        case "settings.set":
            guard ["string", "int", "float", "bool", "date", "data", "json"].contains(p["type"] as? String ?? "string"),
                  PropertyListSerialization.propertyList(p["value"]!, isValidFor: .binary) else { throw TestError.failure }
            mutations += 1
            if failInterval && p["key"] as? String == "BBActiveBacklightHysteresisInterval" {
                failInterval = false; throw TestError.failure
            }
            settings[key()] = ["exists": true, "value": p["value"]!, "type": p["type"] ?? "string"]
            return [:]
        case "settings.delete": mutations += 1; settings[key()] = nil; return [:]
        case "files.plist":
            if !flagExists { throw VPhoneHomeViewControlsModel.Failure(message: "No such file") }
            return ["plist": flags]
        case "files.write":
            flags = try PropertyListSerialization.propertyList(from: Data((p["content"] as! String).utf8), format: nil) as! [String: Any]
            flagExists = true; return [:]
        case "files.plist_set":
            guard flagExists else { throw TestError.failure }
            mutations += 1
            let k = p["key"] as! String
            if p["remove"] as? Bool == true { flags[k] = nil } else { flags[k] = p["value"] }
            return [:]
        case "files.mkdir": return [:]
        case "files.copy": if failBackup { throw TestError.failure }; return [:]
        case "apps.data_dir": return ["data_path": "/guest/PosterBoard"]
        case "services.kickstart":
            guard p["label"] as? String == "com.apple.BreadBoard", p["force"] as? Bool == true else { throw TestError.failure }
            shellRefreshes += 1
            return ["accepted": true, "launchd_status": 0]
        case "script.eval":
            let source = p["source"] as! String
            if source.hasPrefix("ObjC.") { return ["ok": true, "result": "true"] }
            let start = source.firstIndex(of: "[")!, end = source.lastIndex(of: "]")!
            let args = try JSONSerialization.jsonObject(with: Data(source[start...end].utf8)) as! [String]
            var result: [String: Any] = [:]
            if source.contains("homeview-wifi-indicator") {
                if failWifi { return process([:], status: 5) }
                if args[0] != "status" { wifi = args[0] == "enable"; mutations += 1 }
                result = ["wifiActive": wifi, "verified": true]
            } else if source.contains("homeview-location-control") {
                if args[0] != "status" { location = args[0] == "enable"; mutations += 1 }
                result = ["enabled": location]
            } else if source.contains("homeview-personal-content") {
                if args[0] == "list" { result = ["profiles": [["id": profile, "name": "Demo"]]] }
                else {
                    if args[0] != "status" { personal = args[0] == "enable"; mutations += 1 }
                    result = ["current": personal]
                }
            } else if source.contains("home-modular-control") {
                switch args[0] {
                case "list": result = ["value": faces.map { "\($0.0):configuration:\($0.1)(\($0.2))" }.joined(separator: "\n"), "error": "null"]
                case "active-id": result = ["value": selected, "error": "null"]
                case "select": selected = args[1]; result = ["value": "selected", "error": "null"]
                case "create-provider":
                    creates += 1; selected = UUID().uuidString
                    faces.append((args[1], args[2], selected)); result = ["value": selected, "error": "null"]
                default: throw TestError.failure
                }
            }
            return process(result)
        default: throw TestError.failure
        }
    }
    private func process(_ result: [String: Any], status: Int = 0) -> [String: Any] {
        let stdout = String(decoding: try! JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        let process: [String: Any] = ["status": status, "stdout": stdout, "stderr": ""]
        return ["ok": true, "crashed": false, "result": String(decoding: try! JSONSerialization.data(withJSONObject: process), as: UTF8.self)]
    }
}
private enum TestError: Error { case failure }
@main struct HomeViewControlsTests {
    @MainActor static func main() async throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ text: String) {
            precondition(condition(), text); count += 1
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["homeview-wifi-indicator", "homeview-location-control", "homeview-personal-content", "home-modular-control"] {
            try Data("test fixture".utf8).write(to: directory.appendingPathComponent(name))
        }
        let g = Guest()
        let m = VPhoneHomeViewControlsModel(connected: { g.online }, request: { try g.call($0, $1) }, upload: { _, _ in g.uploads += 1 }, resources: directory)
        await m.refresh()
        check(g.mutations == 0, "Refresh must not change settings")
        check(g.uploads == 4, "Helpers deploy automatically")
        check(m.profiles.count == 1 && m.selectedProfile == g.profile, "Discover profiles without a hardcoded UUID")
        check(m.faces.count == 1, "Parse the native face inventory")
        check(m.values[.wifi] == false && m.values[.location] == false, "Read actual helper state")
        await m.set(.wifi, enabled: true)
        check(m.values[.wifi] == true, "Wi-Fi writes need readback")
        g.failWifi = true; await m.refresh()
        check(m.values[.wifi] == nil && m.errors[.wifi] != nil, "Failed reads must not display Off")
        let mutations = g.mutations; await m.set(.wifi, enabled: false)
        check(g.mutations == mutations && m.values[.wifi] == nil, "A failed Wi-Fi publisher must not report success")
        g.failWifi = false
        await m.set(.wifi, enabled: true)
        check(m.values[.wifi] == true && m.errors[.wifi] == nil, "Allow an explicit verified Wi-Fi override when the initial state is unknown")
        let domain = "com.apple.BreadBoard/"
        g.settings[domain + "BBActiveBacklightHysteresisInterval"] = ["exists": true, "value": 123.0, "type": "float"]
        await m.refresh(); await m.set(.keepAwake, enabled: true)
        check(m.values[.keepAwake] == true, "Keep-awake configuration reads back")
        await m.set(.keepAwake, enabled: false)
        check(g.settings[domain + "BBDisplayOffLocalizedSetting"] == nil, "Restore absent keys as absent")
        check(g.settings[domain + "BBActiveBacklightHysteresisInterval"]?["value"] as? Double == 123, "Restore original numeric settings")
        g.failInterval = true; await m.set(.keepAwake, enabled: true)
        check(m.error != nil && m.values[.keepAwake] == false, "Partial writes report failure and restore readback")
        check(g.settings[domain + "BBDisplayOffLocalizedSetting"] == nil, "Roll back the first write when the second fails")
        check(g.settings[domain + "BBActiveBacklightHysteresisInterval"]?["value"] as? Double == 123, "Rollback preserves custom values")
        await m.set(.airPlayVideo, enabled: true)
        check(m.values[.airPlayVideo] == true, "AirPlay configuration reads back")
        check((g.flags["Unrelated"] as? [String: Bool])?["Enabled"] == true, "Preserve unrelated feature flags")
        await m.set(.airPlayVideo, enabled: false)
        check(g.flags["PebbleAirPlayVideoInNowPlaying"] == nil, "Restore originally absent AirPlay override")
        check(m.restartRecommended, "Mark reboot-dependent changes")
        g.flags = [:]; g.flagExists = false
        await m.set(.airPlayVideo, enabled: true)
        check(g.flagExists && m.values[.airPlayVideo] == true, "Create a new plist when no AirPlay override file exists")
        await m.set(.airPlayVideo, enabled: false)
        check(g.flags.isEmpty, "Removing an added AirPlay flag preserves an empty file")
        g.flags = ["PebbleAirPlayVideoInNowPlaying": ["Enabled": true, "OtherField": "preserve"]]
        await m.set(.airPlayVideo, enabled: true); await m.set(.airPlayVideo, enabled: false)
        check((g.flags["PebbleAirPlayVideoInNowPlaying"] as? [String: Any])?["OtherField"] as? String == "preserve", "Restore the complete prior AirPlay dictionary")
        await m.refreshHomeScreen()
        check(g.shellRefreshes == 1 && m.error == nil, "Refresh only the guest shell and require accepted readback")
        await m.set(.personalContent, enabled: true)
        check(g.personal && m.values[.personalContent] == true, "Update only the selected profile")
        await m.addFaces(allMissing: true)
        check(g.creates == 1, "Only add missing presets")
        check(g.selected == g.originalFace, "Restore selection after adding a preset")
        await m.addFaces(allMissing: true)
        check(g.creates == 1, "Repeated additions skip existing presets")
        g.faces.removeLast(); g.failBackup = true
        await m.addFaces(allMissing: true)
        check(g.creates == 1 && m.error != nil, "Refuse face creation if the backup fails")
        g.online = false; let before = g.mutations
        await m.set(.location, enabled: true)
        check(g.mutations == before, "Disconnected actions must not write")
        print("Passed \(count) HomeView controls state, rollback, and face-management checks")
    }
}

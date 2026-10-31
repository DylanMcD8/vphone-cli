import Foundation
import Observation

@MainActor @Observable
final class VPhoneHomeViewControlsModel {
    enum Feature: String, CaseIterable {
        case keepAwake, wifi, location, personalContent, airPlayVideo
        var title: String {
            switch self {
            case .keepAwake: "Keep Display Awake"
            case .wifi: "Hide Disconnected Wi-Fi Indicator"
            case .location: "Location Services"
            case .personalContent: "Personal Content"
            case .airPlayVideo: "Use Separate AirPlay Video Player"
            }
        }
        var detail: String {
            switch self {
            case .keepAwake: "Prevents automatic dimming and screen-off. Restart HomeView to apply."
            case .wifi: "Cosmetic only. Reapply after restarting or if the warning returns. Off publishes disconnected status."
            case .location: "Enables the guest’s Location Services switch. App permissions remain separate."
            case .personalContent: "Changes the selected profile’s setting. It does not sign in or supply account content."
            case .airPlayVideo: "Uses the tested video presentation workaround. Restart HomeView and reconnect AirPlay to apply."
            }
        }
    }
    struct Profile: Identifiable { let id: String; let name: String }
    struct Face: Identifiable { let id: String; let provider: String; let descriptor: String }
    struct Preset: Decodable, Identifiable {
        let name: String; let provider: String; let descriptor: String
        var id: String { provider + ":" + descriptor }
    }
    struct Failure: LocalizedError { let message: String; var errorDescription: String? { message } }
    typealias Request = @MainActor (String, [String: Any]) async throws -> [String: Any]
    typealias Upload = @MainActor (String, Data) async throws -> Void
    @ObservationIgnored private let connected: @MainActor () -> Bool
    @ObservationIgnored private let request: Request
    @ObservationIgnored private let upload: Upload
    @ObservationIgnored private let resources: URL?
    @ObservationIgnored private let prepareManualLocation: @MainActor () -> Void
    @ObservationIgnored private var installed = Set<String>()
    private(set) var isConnected = false
    private(set) var isBusy = false
    private(set) var values: [Feature: Bool] = [:]
    private(set) var errors: [Feature: String] = [:]
    private(set) var profiles: [Profile] = []
    private(set) var faces: [Face] = []
    private(set) var presets: [Preset] = []
    private(set) var message = ""
    private(set) var error: String?
    private(set) var restartRecommended = false
    var selectedProfile = ""
    var selectedFace = ""
    var selectedPreset = ""
    private static let journalDomain = "com.vphone.HomeViewControls"
    private static let airPlayPath = "/Library/Preferences/FeatureFlags/Domain/TVAirPlay.plist"
    private static let displayDomain = "com.apple.BreadBoard"
    private static let displayKeys = ["BBDisplayOffLocalizedSetting", "BBActiveBacklightHysteresisInterval"]

    init(connected: @escaping @MainActor () -> Bool, request: @escaping Request, upload: @escaping Upload, resources: URL?, prepareManualLocation: @escaping @MainActor () -> Void = {}) {
        self.connected = connected; self.request = request; self.upload = upload; self.resources = resources
        self.prepareManualLocation = prepareManualLocation
        presets = [Preset(name: "Home Modular — normal", provider: "com.apple.Home.HomeFace", descriptor: "default-color-1"),
                   Preset(name: "Home Modular — nine sample tiles", provider: "com.apple.Home.HomeFace", descriptor: "HomeControlFace-featured8")]
        if let resources, let data = try? Data(contentsOf: resources.appendingPathComponent("AdditionalFaces.json")),
           let additional = try? JSONDecoder().decode([Preset].self, from: data) { presets += additional }
        selectedPreset = presets.first?.id ?? ""
    }

    func run() async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { break }
            if isConnected != connected() {
                installed.removeAll(); values.removeAll(); errors.removeAll(); profiles = []; faces = []
                isConnected = connected()
                if isConnected && !isBusy { await refresh() }
            }
        }
    }

    func refresh() async {
        guard !isBusy else { return }
        isConnected = connected()
        guard isConnected else { values = [:]; return }
        isBusy = true; defer { isBusy = false }
        error = nil
        do { try await readProfiles() } catch { self.error = error.localizedDescription }
        for feature in Feature.allCases { await read(feature) }
        do { try await readFaces() } catch { self.error = error.localizedDescription }
    }

    func changeProfile() async {
        guard !isBusy, connected() else { return }
        isBusy = true; defer { isBusy = false }
        values[.personalContent] = nil
        await read(.personalContent)
    }

    func set(_ feature: Feature, enabled: Bool) async {
        guard !isBusy, connected(), values[feature] != nil || feature == .wifi else { return }
        isBusy = true; defer { isBusy = false }
        error = nil; message = ""
        do {
            switch feature {
            case .wifi:
                let result = try await helper("homeview-wifi-indicator", [enabled ? "enable" : "disable"])
                guard result["verified"] as? Bool == true, result["wifiActive"] as? Bool == enabled else {
                    throw Failure(message: "HomeView did not confirm the Wi-Fi display override.")
                }
                values[.wifi] = enabled; errors[.wifi] = nil
            case .location:
                _ = try await helper("homeview-location-control", [enabled ? "enable" : "disable"])
            case .personalContent:
                guard profiles.contains(where: { $0.id == selectedProfile }) else { throw Failure(message: "Choose a profile first.") }
                _ = try await helper("homeview-personal-content", [enabled ? "enable" : "disable", selectedProfile])
            case .keepAwake:
                try await setKeepAwake(enabled)
                restartRecommended = true
            case .airPlayVideo:
                try await setAirPlay(enabled)
                restartRecommended = true
            }
            // The publisher verifies its own update. On retail tvOS a new
            // read-only SystemStatus client may never receive initial data.
            if feature != .wifi { await read(feature) }
            guard values[feature] == enabled else { throw Failure(message: "HomeView did not confirm the requested setting. Refresh before trying again.") }
            message = feature.title + (enabled ? " enabled." : " disabled.")
        } catch {
            self.error = error.localizedDescription
            installed.removeAll() // A reboot clears /var/tmp; never trust a cached upload after failure.
            await read(feature)
        }
    }

    private func read(_ feature: Feature) async {
        values[feature] = nil; errors[feature] = nil
        do {
            let value: Bool
            switch feature {
            case .wifi:
                let r = try await helper("homeview-wifi-indicator", ["status"])
                guard let active = r["wifiActive"] as? Bool else { throw Failure(message: "No Wi-Fi status readback.") }
                value = active
            case .location:
                let r = try await helper("homeview-location-control", ["status"])
                guard let enabled = r["enabled"] as? Bool else { throw Failure(message: "No Location Services readback.") }
                value = enabled
            case .personalContent:
                guard profiles.contains(where: { $0.id == selectedProfile }) else { throw Failure(message: "No local profile selected. Set up a profile in HomeView first.") }
                let r = try await helper("homeview-personal-content", ["status", selectedProfile])
                guard let current = r["current"] as? Bool else { throw Failure(message: "Personal Content has no explicit value for this profile.") }
                value = current
            case .keepAwake:
                let off = try await setting(Self.displayDomain, Self.displayKeys[0])
                let interval = try await setting(Self.displayDomain, Self.displayKeys[1])
                value = off["value"] as? String == "PSAlwaysActiveDisplayTurnOffNever" && (interval["value"] as? NSNumber)?.doubleValue == 2_147_483_647
            case .airPlayVideo:
                let dictionary = try await optionalPlist(Self.airPlayPath)
                value = (dictionary?["PebbleAirPlayVideoInNowPlaying"] as? [String: Any])?["Enabled"] as? Bool == false
            }
            values[feature] = value
        } catch {
            let text = error.localizedDescription
            errors[feature] = feature == .wifi && text.contains("No SystemStatus response")
                ? "HomeView has not supplied an initial Wi-Fi status." : text
        }
    }

    func openNowPlaying() async {
        await action {
            // LaunchServices is also used by the daemon's normal app launcher.
            let result = try await self.request("script.eval", ["source": "ObjC.use('LSApplicationWorkspace').defaultWorkspace().openApplicationWithBundleID_('com.apple.pebblenowplaying')", "timeout": 10])
            guard result["ok"] as? Bool == true, result["crashed"] as? Bool != true,
                  (result["result"] as? String == "true" || result["result"] as? String == "1") else {
                throw Failure(message: "HomeView could not open Now Playing. Start an AirPlay session, then try again.")
            }
            self.message = "Now Playing opened. Select HomeView in the Mac’s AirPlay menu to supply artwork and track information."
        }
    }

    func useCupertino() async {
        await action {
            let result = try await self.helper("homeview-location-control", ["enable"])
            guard result["enabled"] as? Bool == true else { throw Failure(message: "Location Services did not enable.") }
            self.prepareManualLocation()
            _ = try await self.request("location.set", ["latitude": 37.3349, "longitude": -122.009, "altitude": 30])
            let r = try await self.request("location.current", [:])
            guard r["simulated"] as? Bool == true,
                  let latitude = r["latitude"] as? Double, let longitude = r["longitude"] as? Double,
                  abs(latitude - 37.3349) < 0.0001, abs(longitude + 122.009) < 0.0001 else {
                throw Failure(message: "Location was sent, but HomeView did not confirm the simulated Cupertino position.")
            }
            self.values[.location] = true
            self.message = "Cupertino location applied."
        }
    }

    func restart() async {
        await action {
            _ = try await self.request("system.reboot", ["force": true])
            self.installed.removeAll(); self.values = [:]; self.isConnected = false
            self.restartRecommended = false; self.message = "HomeView is restarting."
        }
    }

    func refreshHomeScreen() async {
        await action {
            let result = try await self.request("services.kickstart", ["label": "com.apple.BreadBoard", "kill": true, "force": true])
            guard result["accepted"] as? Bool == true, result["launchd_status"] as? Int == 0 else {
                throw Failure(message: "HomeView did not confirm the home-screen refresh.")
            }
            self.message = "Home screen refreshed. Temporary recognition overrides may need reapplying."
        }
    }

    func selectFace() async {
        guard let face = faces.first(where: { $0.id == selectedFace }) else { return }
        await action {
            _ = try await self.helper("home-modular-control", ["select", face.id])
            self.message = "Face selected. Return from an app to the clock to view it."
        }
    }

    func addFaces(allMissing: Bool) async {
        await action {
            try await self.readFaces()
            let wanted = allMissing ? self.presets : self.presets.filter { $0.id == self.selectedPreset }
            let missing = wanted.filter { p in !self.faces.contains { $0.provider == p.provider && $0.descriptor == p.descriptor } }
            guard !missing.isEmpty else { self.message = "These face presets are already installed."; return }
            let active = try await self.helper("home-modular-control", ["active-id"])["value"] as? String
            guard let active, UUID(uuidString: active) != nil else { throw Failure(message: "Could not record the current face selection.") }
            let poster = try await self.request("apps.data_dir", ["bundle_id": "com.apple.PosterBoard"])
            guard let directory = poster["data_path"] as? String else { throw Failure(message: "Could not locate the face store for backup.") }
            let backup = "/var/mobile/Library/HomeViewControls/FaceBackups/" + UUID().uuidString
            _ = try await self.request("files.mkdir", ["path": backup])
            _ = try await self.request("files.copy", ["from": directory + "/Library/Application Support/PRBPosterExtensionDataStore", "to": backup + "/Store"])
            var creationError: Error?
            do {
                for p in missing { _ = try await self.helper("home-modular-control", ["create-provider", p.provider, p.descriptor]) }
            } catch { creationError = error }
            // Creation selects its new face. Restore even after a partial batch failure.
            _ = try await self.helper("home-modular-control", ["select", active])
            try await self.readFaces()
            if let creationError { throw creationError }
            self.message = "Added \(missing.count) face presets. Existing faces and the prior selection were preserved."
        }
    }

    private func readProfiles() async throws {
        profiles = []
        let result = try await helper("homeview-personal-content", ["list"])
        guard let entries = result["profiles"] as? [[String: Any]] else { throw Failure(message: "Invalid profile inventory.") }
        profiles = entries.compactMap { p in
            guard let id = p["id"] as? String, UUID(uuidString: id) != nil else { return nil }
            return Profile(id: id, name: p["name"] as? String ?? id)
        }
        if !profiles.contains(where: { $0.id == selectedProfile }) { selectedProfile = profiles.count == 1 ? profiles[0].id : "" }
    }

    private func readFaces() async throws {
        faces = []
        let result = try await helper("home-modular-control", ["list"])
        guard let description = result["value"] as? String else { throw Failure(message: "Invalid face inventory.") }
        faces = Self.parseFaces(description)
        guard !faces.isEmpty else { throw Failure(message: "HomeView returned no readable face configurations.") }
        if !faces.contains(where: { $0.id == selectedFace }) {
            let active = try await helper("home-modular-control", ["active-id"])["value"] as? String
            selectedFace = faces.first { $0.id == active }?.id ?? faces[0].id
        }
    }

    static func parseFaces(_ text: String) -> [Face] {
        let pattern = #"(com\.apple\.[^\n]*?):configuration:(.*?)\(([A-Fa-f0-9-]{36})\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = text as NSString
        return regex.matches(in: text as String, range: NSRange(location: 0, length: text.length)).compactMap { m in
            let id = text.substring(with: m.range(at: 3))
            guard UUID(uuidString: id) != nil else { return nil }
            return Face(id: id, provider: text.substring(with: m.range(at: 1)), descriptor: text.substring(with: m.range(at: 2)))
        }
    }

    private func setKeepAwake(_ enabled: Bool) async throws {
        let journalKey = "DisplayOriginal"
        if enabled {
            if try await setting(Self.journalDomain, journalKey)["exists"] as? Bool != true {
                var original: [String: Any] = [:]
                for key in Self.displayKeys { original[key] = try Self.preferenceSnapshot(await setting(Self.displayDomain, key)) }
                _ = try await request("settings.set", ["domain": Self.journalDomain, "key": journalKey, "value": original, "type": "json"])
            }
            do {
                _ = try await request("settings.set", ["domain": Self.displayDomain, "key": Self.displayKeys[0], "value": "PSAlwaysActiveDisplayTurnOffNever", "type": "string"])
                _ = try await request("settings.set", ["domain": Self.displayDomain, "key": Self.displayKeys[1], "value": 2_147_483_647, "type": "float"])
            } catch {
                try await restoreDisplay()
                throw error
            }
        } else { try await restoreDisplay() }
    }

    private func restoreDisplay() async throws {
        let original = try await setting(Self.journalDomain, "DisplayOriginal")["value"] as? [String: [String: Any]]
        for key in Self.displayKeys {
            try await restoreSetting(Self.displayDomain, key, original?[key])
        }
        _ = try await request("settings.delete", ["domain": Self.journalDomain, "key": "DisplayOriginal"])
    }

    private func restoreSetting(_ domain: String, _ key: String, _ original: [String: Any]?) async throws {
        if let original, original["exists"] as? Bool == true, let value = original["value"] {
            var params: [String: Any] = ["domain": domain, "key": key, "value": value]
            if let type = original["type"] as? String {
                params["type"] = ["dictionary", "array"].contains(type) ? "json" : type
            }
            _ = try await request("settings.set", params)
        } else { _ = try await request("settings.delete", ["domain": domain, "key": key]) }
    }

    private func setAirPlay(_ enabled: Bool) async throws {
        let key = "PebbleAirPlayVideoInNowPlaying"
        let file = try await optionalPlist(Self.airPlayPath)
        let saved = try await setting(Self.journalDomain, "AirPlayOriginal")
        if enabled {
            if saved["exists"] as? Bool != true {
                var original: [String: Any] = ["exists": file?[key] != nil]
                if let value = file?[key] { original["value"] = value }
                _ = try await request("settings.set", ["domain": Self.journalDomain, "key": "AirPlayOriginal", "value": original, "type": "json"])
            }
            _ = try await request("files.mkdir", ["path": "/Library/Preferences/FeatureFlags/Domain"])
            if let existing = file?[key], !(existing is [String: Any]) {
                throw Failure(message: "The existing AirPlay override is not a dictionary. It was preserved.")
            }
            var flag = file?[key] as? [String: Any] ?? [:]
            flag["Enabled"] = false
            if file == nil {
                let data = try PropertyListSerialization.data(fromPropertyList: [key: flag], format: .xml, options: 0)
                _ = try await request("files.write", ["path": Self.airPlayPath, "content": String(decoding: data, as: UTF8.self), "encoding": "utf8"])
            } else {
                _ = try await request("files.plist_set", ["path": Self.airPlayPath, "key": key, "value": flag])
            }
        } else {
            if let original = saved["value"] as? [String: Any], original["exists"] as? Bool == true, let value = original["value"] {
                _ = try await request("files.plist_set", ["path": Self.airPlayPath, "key": key, "value": value])
            } else if file?[key] != nil {
                _ = try await request("files.plist_set", ["path": Self.airPlayPath, "key": key, "remove": true])
            }
            _ = try await request("settings.delete", ["domain": Self.journalDomain, "key": "AirPlayOriginal"])
        }
    }

    private func setting(_ domain: String, _ key: String) async throws -> [String: Any] {
        try await request("settings.get", ["domain": domain, "key": key])
    }

    static func preferenceSnapshot(_ result: [String: Any]) throws -> [String: Any] {
        guard let exists = result["exists"] as? Bool else { throw Failure(message: "The guest did not report preference existence.") }
        guard exists else { return ["exists": false] }
        guard let value = result["value"], !(value is NSNull), let type = result["type"] as? String else {
            throw Failure(message: "The original preference could not be preserved.")
        }
        return ["exists": true, "value": value, "type": type]
    }

    private func optionalPlist(_ path: String) async throws -> [String: Any]? {
        do {
            let r = try await request("files.plist", ["path": path])
            guard let value = r["plist"] as? [String: Any] else { throw Failure(message: "Invalid property list at \(path)") }
            return value
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("no such file") || message.contains("does not exist") { return nil }
            throw error
        }
    }

    private func helper(_ name: String, _ arguments: [String]) async throws -> [String: Any] {
        guard connected() else { throw Failure(message: "HomeView is disconnected.") }
        if !installed.contains(name) {
            guard let url = resources?.appendingPathComponent(name) else { throw Failure(message: "This app is missing its HomeView tools. Rebuild the bundle.") }
            let data = try Data(contentsOf: url)
            try await upload("/var/tmp/" + name, data)
            installed.insert(name)
        }
        let encoded = String(decoding: try JSONSerialization.data(withJSONObject: arguments), as: UTF8.self)
        let result = try await request("script.eval", ["source": "proc.run('/var/tmp/\(name)',\(encoded))", "timeout": 30])
        guard result["ok"] as? Bool == true, result["crashed"] as? Bool != true,
              let wire = result["result"] as? String,
              let process = try JSONSerialization.jsonObject(with: Data(wire.utf8)) as? [String: Any],
              process["status"] as? Int == 0 else {
            installed.remove(name)
            throw Failure(message: "\(name) failed: \(result["error"] ?? result["result"] ?? "No result")")
        }
        let output = process["stdout"] as? String ?? ""
        guard let line = output.split(separator: "\n").first,
              let value = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { throw Failure(message: "\(name) returned no readable result.") }
        if let error = value["error"] as? String, error != "null" { throw Failure(message: error) }
        return value
    }

    private func action(_ work: () async throws -> Void) async {
        guard !isBusy, connected() else { return }
        isBusy = true; error = nil; message = ""
        defer { isBusy = false }
        do { try await work() } catch { self.error = error.localizedDescription; installed.removeAll() }
    }
}

import SwiftUI

struct VPhoneHomeViewControlsView: View {
    @Bindable var model: VPhoneHomeViewControlsModel
    let control: VPhoneGuestControl
    @State private var confirmsRestart = false
    @State private var confirmsHomeRefresh = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Display and Connection Status") {
                    setting(.keepAwake)
                    Button("Refresh Home Screen…") { confirmsHomeRefresh = true }
                    Text("Refreshes cached icons, including Calendar after a guest date change. The interface briefly reloads; temporary recognition overrides may need reapplying.")
                        .font(.caption).foregroundStyle(.secondary)
                    setting(.wifi)
                    if model.values[.wifi] == nil {
                        HStack {
                            Button("Hide Wi-Fi Warning") { Task { await model.set(.wifi, enabled: true) } }
                            Button("Show Wi-Fi Warning") { Task { await model.set(.wifi, enabled: false) } }
                        }
                        Text("HomeView may not report initial Wi-Fi status. These actions apply an explicit override and verify the result.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Location") {
                    setting(.location)
                    Button("Use Cupertino Demo Location") { Task { await model.useCupertino() } }
                    Text("Supply a place for location-aware previews. Weather and other services can still require authentication.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Personal Content") {
                    Picker("Profile", selection: $model.selectedProfile) {
                        Text("Choose a profile").tag("")
                        ForEach(model.profiles) { p in Text(p.name).tag(p.id) }
                    }
                    .onChange(of: model.selectedProfile) { _, _ in Task { await model.changeProfile() } }
                    setting(.personalContent)
                    Text("Recognition and paired-device requirements remain separate. This control does not create an Apple Account or bypass recognition.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("AirPlay") {
                    setting(.airPlayVideo)
                    Button("Open Now Playing") { Task { await model.openNowPlaying() } }
                    Text("Choose HomeView in the Mac’s Music or video AirPlay menu. Music artwork and controls work as a visual preview; audio playback may stall.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Clock Faces") {
                    Picker("Installed Face", selection: $model.selectedFace) {
                        Text("Choose a face").tag("")
                        ForEach(model.faces) { f in Text(faceName(f)).tag(f.id) }
                    }
                    Button("Select Face") { Task { await model.selectFace() } }
                        .disabled(model.selectedFace.isEmpty)
                    Picker("Face Preset", selection: $model.selectedPreset) {
                        ForEach(model.presets) { p in Text(p.name).tag(p.id) }
                    }
                    HStack {
                        Button("Add Selected Preset") { Task { await model.addFaces(allMissing: false) } }
                        Button("Add All Missing Presets") { Task { await model.addFaces(allMissing: true) } }
                    }
                    Text("Adding presets backs up the face store, skips existing presets, and restores the previous selection. Gallery samples use Apple’s built-in demo tiles; a configured HomeKit home may replace them.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VPhoneHomeViewDistanceSection(control: control)
                Section("Setup") {
                    Text("The initial setup bypass is selected during firmware installation. This panel changes runtime controls and preserves existing setup and profiles.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .disabled(!model.isConnected || model.isBusy)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                if let error = model.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                }
                if !model.message.isEmpty { Text(model.message).textSelection(.enabled) }
                if model.restartRecommended {
                    HStack {
                        Text("Restart HomeView to apply the display or video changes.")
                        Spacer()
                        Button("Restart HomeView…") { confirmsRestart = true }
                            .disabled(!model.isConnected || model.isBusy)
                    }
                }
                HStack {
                    Circle().fill(model.isConnected ? Color.green : Color.secondary).frame(width: 7, height: 7)
                    Text(model.isConnected ? "Connected" : "Waiting for HomeView…")
                    Spacer()
                    if model.isBusy { ProgressView().controlSize(.small) }
                }.foregroundStyle(.secondary)
            }
            .font(.callout).padding(12)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }
                    .disabled(model.isBusy || !model.isConnected)
            }
        }
        .confirmationDialog("Restart HomeView?", isPresented: $confirmsRestart) {
            Button("Restart HomeView", role: .destructive) { Task { await model.restart() } }
        } message: { Text("This ends the current AirPlay session and restarts the guest.") }
        .confirmationDialog("Refresh HomeView’s home screen?", isPresented: $confirmsHomeRefresh) {
            Button("Refresh Home Screen") { Task { await model.refreshHomeScreen() } }
        } message: { Text("The interface briefly reloads. Temporary recognition overrides may need reapplying.") }
        .task { await model.run() }
    }

    @ViewBuilder private func setting(_ feature: VPhoneHomeViewControlsModel.Feature) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(feature.title, isOn: Binding(
                get: { model.values[feature] ?? false },
                set: { enabled in Task { await model.set(feature, enabled: enabled) } },
            ))
            .disabled(model.values[feature] == nil)
            Text(feature.detail).font(.caption).foregroundStyle(.secondary)
            if let error = model.errors[feature] {
                Text("Unavailable: " + error).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }

    private func faceName(_ face: VPhoneHomeViewControlsModel.Face) -> String {
        let name = model.presets.first { $0.provider == face.provider && $0.descriptor == face.descriptor }?.name
            ?? face.descriptor
        return name + " · " + face.id.prefix(8)
    }
}

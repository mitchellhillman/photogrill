import SwiftUI
import AppKit

struct SettingsPanel: View {
    @ObservedObject var settings: ExportSettings
    @ObservedObject var exportEngine: ExportEngine
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)
                    .padding(.bottom, 4)

                // Quality
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Text("\(Int(settings.quality * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.quality, in: 0.1...1.0, step: 0.05)
                }

                Divider()

                // Max dimension
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Limit size", isOn: $settings.maxDimensionEnabled)
                    if settings.maxDimensionEnabled {
                        HStack {
                            TextField("px", value: $settings.maxDimension, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("px on long edge")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Divider()

                // Output folder
                VStack(alignment: .leading, spacing: 6) {
                    Text("Output folder")
                    HStack(spacing: 4) {
                        Text(settings.outputFolder?.lastPathComponent ?? "Same as source")
                            .font(.caption)
                            .foregroundStyle(settings.outputFolder == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Choose…") { chooseFolder() }
                            .controlSize(.small)
                        if settings.outputFolder != nil {
                            Button {
                                settings.outputFolder = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                // Exposure
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Exposure")
                        Spacer()
                        Text(exposureLabel)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.exposure, in: -3.0...3.0, step: 0.1)
                    HStack {
                        Text("-3").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("+3").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Color profile
                VStack(alignment: .leading, spacing: 4) {
                    Text("Color profile")
                    Picker("", selection: $settings.colorProfile) {
                        ForEach(ColorProfile.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                // White balance
                VStack(alignment: .leading, spacing: 4) {
                    Text("White balance")
                    Picker("", selection: $settings.whiteBalance) {
                        ForEach(WhiteBalance.allCases) { wb in
                            Text(wb.rawValue).tag(wb)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Spacer(minLength: 16)

                // Actions
                HStack {
                    Button("Clear all") {
                        appState.items.removeAll()
                        appState.selectedID = nil
                    }
                    .foregroundStyle(.red)
                    Spacer()
                    Button("Export All") {
                        exportEngine.exportAll(items: appState.items, settings: settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.items.isEmpty || exportEngine.isExporting)
                }

                if exportEngine.isExporting {
                    ProgressView("Exporting \(exportEngine.completedCount) / \(appState.items.count)…")
                        .progressViewStyle(.linear)
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
    }

    private var exposureLabel: String {
        let v = settings.exposure
        if v == 0 { return "0 EV" }
        return String(format: "%+.1f EV", v)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK {
            settings.outputFolder = panel.url
        }
    }
}

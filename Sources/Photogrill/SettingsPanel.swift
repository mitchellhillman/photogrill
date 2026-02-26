import SwiftUI
import AppKit

/// NSSlider wrapper that shows tick marks at every 0.5-stop increment.
private struct TickedExposureSlider: NSViewRepresentable {
    @Binding var value: Double

    // -3 … +3 EV, ticks at 0.5-stop intervals → 13 marks
    private let min = -3.0
    private let max =  3.0
    private let tickCount = 13   // (-3, -2.5, …, 0, …, +2.5, +3)

    func makeCoordinator() -> Coordinator { Coordinator(value: $value) }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: min, maxValue: max,
                              target: context.coordinator,
                              action: #selector(Coordinator.valueChanged(_:)))
        slider.numberOfTickMarks = tickCount
        slider.tickMarkPosition  = .below
        slider.allowsTickMarkValuesOnly = false   // free dragging; ticks are visual only
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = value
    }

    class Coordinator: NSObject {
        var value: Binding<Double>
        init(value: Binding<Double>) { self.value = value }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

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
                    TickedExposureSlider(value: $settings.exposure)
                        .frame(height: 28)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text("White balance")
                    Picker("", selection: $settings.whiteBalance) {
                        ForEach(WhiteBalance.allCases) { wb in
                            Text(wb.rawValue).tag(wb)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .onChange(of: settings.whiteBalance) { wb in
                        // Snap kelvin slider to preset value when a preset is chosen
                        if let k = wb.kelvin { settings.kelvin = Double(k) }
                    }

                    HStack {
                        Text("Kelvin")
                        Spacer()
                        Text("\(Int(settings.kelvin)) K")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { settings.kelvin },
                        set: {
                            settings.kelvin = $0
                            if settings.whiteBalance == .asShot || settings.whiteBalance == .auto {
                                settings.whiteBalance = .custom
                            }
                        }
                    ), in: 2000...10000, step: 50)
                    // Gradient legend bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.45, green: 0.65, blue: 1.00), location: 0.00), // 10000 K cool blue
                                .init(color: Color(red: 0.80, green: 0.90, blue: 1.00), location: 0.32), // ~7500 K pale blue
                                .init(color: Color(red: 1.0, green: 0.97, blue: 0.95), location: 0.57), // ~5500 K neutral
                                .init(color: Color(red: 1.0, green: 0.88, blue: 0.65), location: 0.80), // ~3600 K golden
                                .init(color: Color(red: 1.0, green: 0.55, blue: 0.10), location: 1.00), // 2000 K warm amber
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 8)
                    HStack {
                        Text("2000 K").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("10000 K").font(.caption2).foregroundStyle(.secondary)
                    }
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

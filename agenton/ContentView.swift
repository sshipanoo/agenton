import SwiftUI

struct MenuBarContent: View {
    @Environment(PowerManager.self) private var power
    @Environment(LicenseManager.self) private var license
    @Environment(PowerSourceMonitor.self) private var source
    @State private var showingCustomPicker = false
    @State private var customDisableTime = Date().addingTimeInterval(3600)

    var body: some View {
        @Bindable var p = power

        VStack(spacing: 0) {
            statusHeader
            Divider()
            controlArea(bindable: $p)
            Divider()
            footer
        }
        .frame(width: 260)
    }

    // MARK: - Status header

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(power.isActive ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 7, height: 7)
                .shadow(color: power.isActive ? .green.opacity(0.5) : .clear, radius: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(power.isActive ? "AGENT ON DUTY" : "AGENT OFF DUTY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(power.isActive ? .primary : .secondary)

                if power.isActive, let start = power.sessionStart {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        let now = context.date
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatElapsed(from: start, to: now))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                            if let target = power.scheduledDisableAt, target > now {
                                Text("auto-off in \(formatRemaining(until: target, from: now))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.orange.opacity(0.85))
                            }
                        }
                    }
                } else {
                    Text(subtitleText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: source.isOnAC ? "bolt.fill" : "battery.50")
                    .font(.system(size: 11))
                Text(source.isOnAC ? "AC" : "Battery")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(source.isOnAC ? Color.green : Color.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subtitleText: String { "ready to deploy" }

    // MARK: - Controls

    @ViewBuilder
    private func controlArea(bindable: Bindable<PowerManager>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            mainButton
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            hintIfNeeded

            // Auto-disable schedule
            HStack {
                Text("Auto-disable")
                    .font(.system(size: 12))
                    .foregroundStyle(power.isActive ? .primary : .secondary)
                Spacer()
                Menu {
                    Button("Never") { power.cancelSchedule() }
                    Divider()
                    Button("In 30 minutes") { power.scheduleDisable(in: 30 * 60) }
                    Button("In 1 hour")     { power.scheduleDisable(in: 60 * 60) }
                    Button("In 2 hours")    { power.scheduleDisable(in: 2 * 60 * 60) }
                    Button("In 4 hours")    { power.scheduleDisable(in: 4 * 60 * 60) }
                    Button("In 8 hours")    { power.scheduleDisable(in: 8 * 60 * 60) }
                    Divider()
                    Button("At specific date & time…") {
                        customDisableTime = Date().addingTimeInterval(3600)
                        showingCustomPicker = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(scheduleLabel)
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .opacity(0.5)
                    }
                    .foregroundStyle(scheduleChipForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(scheduleChipBackground)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(!power.isActive)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // Inline date-time picker (replaces sheet — sheets get killed by
            // MenuBarExtra's window-style auto-close on focus loss)
            if showingCustomPicker {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("",
                               selection: $customDisableTime,
                               in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            showingCustomPicker = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Set") {
                            power.scheduleDisable(at: customDisableTime)
                            showingCustomPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(customDisableTime <= Date())
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // Auto-enable
            HStack {
                Text("Auto-enable when on AC power")
                    .font(.system(size: 12))
                    .foregroundStyle(license.canEnable ? .primary : .secondary)
                Spacer()
                Toggle("", isOn: bindable.autoOnAC)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .disabled(!license.canEnable)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private var scheduleChipForeground: Color {
        if !power.isActive { return .secondary }
        if power.scheduledDisableAt != nil { return .orange }
        return .primary
    }

    private var scheduleChipBackground: Color {
        if !power.isActive { return Color.secondary.opacity(0.08) }
        if power.scheduledDisableAt != nil { return Color.orange.opacity(0.15) }
        return Color.primary.opacity(0.06)
    }

    private var scheduleLabel: String {
        guard let target = power.scheduledDisableAt else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        // If within next 8 hours, show "in Xh Ym"; otherwise show absolute time
        let remaining = target.timeIntervalSinceNow
        if remaining < 8 * 3600 {
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            if h > 0 { return "in \(h)h \(m)m" }
            return "in \(max(1, m))m"
        }
        return formatter.string(from: target)
    }

    @ViewBuilder
    private var mainButton: some View {
        Button(action: { Task { await power.toggleActive() } }) {
            Text(power.isActive ? "Disable Agent" : "Enable Agent")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(power.isActive ? Color(nsColor: .systemGray) : Color.accentColor)
    }

    @ViewBuilder
    private var hintIfNeeded: some View {
        if power.awaitingHelperApproval {
            hintRow(
                text: "Approve Agent On Helper in System Settings, then click Enable again.",
                icon: "lock.shield",
                color: .orange
            )
        } else if let err = power.lastError {
            hintRow(text: err, icon: "xmark.circle", color: .red)
        } else if !power.isActive {
            hintRow(
                text: source.isOnAC
                    ? "First run installs a privileged helper (one-time approval)"
                    : "Connect power before enabling",
                icon: source.isOnAC ? "lock.shield" : "exclamationmark.triangle",
                color: source.isOnAC ? .secondary : .orange
            )
        }
    }

    private func hintRow(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 10))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Agent On")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") {
                Task {
                    if power.isActive { await power.disable() }
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Helpers

    private func formatElapsed(from start: Date, to end: Date) -> String {
        let t = max(0, Int(end.timeIntervalSince(start)))
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        if h > 0 { return String(format: "%dh %02dm %02ds", h, m, s) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    private func formatRemaining(until target: Date, from now: Date) -> String {
        let t = max(0, Int(target.timeIntervalSince(now)))
        let h = t / 3600
        let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }
}



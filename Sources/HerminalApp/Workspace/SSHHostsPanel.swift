// SSHHostsPanel — left-sidebar SSH connection manager.
// Lists saved hosts; inline form for add/edit; emits onConnect when the user
// wants to launch a session (the actual spawn happens in M4-4).

import SwiftUI
import HerminalDB

struct SSHHostsPanel: View {
    let hosts: [SSHHost]
    let onConnect: (SSHHost) -> Void
    let onSave: (SSHHost) -> Void
    let onDelete: (UUID) -> Void

    enum Mode: Equatable {
        case list
        case editing(SSHHost?) // nil = new host
    }

    @State private var mode: Mode = .list
    @State private var pendingDelete: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(HerminalDesign.Palette.divider)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HerminalDesign.Palette.surfaceElevated)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Text("SSH HOSTS")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            switch mode {
            case .list:
                Text("\(hosts.count)")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .accessibilityLabel("\(hosts.count) saved host\(hosts.count == 1 ? "" : "s")")
                AddHostButton { mode = .editing(nil) }
            case .editing:
                Button("Cancel") { mode = .list }
                    .font(HerminalDesign.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .accessibilityLabel("Cancel host editing")
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.md)
        .frame(height: TabBarView.barHeight)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .list:
            listView
        case .editing(let existing):
            SSHHostFormView(existing: existing) { saved in
                onSave(saved)
                mode = .list
            }
            .padding(HerminalDesign.Spacing.sm)
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listView: some View {
        if hosts.isEmpty {
            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xs) {
                Text("No hosts yet")
                    .font(HerminalDesign.Typography.body)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                Text("Tap + to save your first connection.")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HerminalDesign.Spacing.md)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                    ForEach(hosts) { host in
                        hostRow(host)
                    }
                }
                .padding(HerminalDesign.Spacing.sm)
            }
        }
    }

    private func hostRow(_ host: SSHHost) -> some View {
        SSHHostRow(host: host,
                   onConnect: { onConnect(host) },
                   onEdit: { mode = .editing(host) },
                   onDelete: { onDelete(host.id) })
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

/// One row in the SSH host list. Owns the hover state so the highlight
/// is row-local — sibling rows don't redraw on hover.
private struct SSHHostRow: View {
    let host: SSHHost
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(host.nickname)
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Spacer()
                Button("Connect", action: onConnect)
                    .font(HerminalDesign.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HerminalDesign.Palette.accent)
                    .accessibilityLabel("Connect to \(host.nickname)")
                    .accessibilityHint("Opens a new tab running ssh against this host")
            }
            Text("\(host.user)@\(host.hostname):\(host.port)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
            if let lastConnected = host.lastConnectedAt {
                Text("Last connected \(SSHHostsPanel.relative(lastConnected))")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(isHovered
                      ? HerminalDesign.Palette.surfaceOverlay.opacity(1.3)
                      : HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(
                    isHovered ? HerminalDesign.Palette.accent.opacity(0.35)
                              : Color.clear,
                    lineWidth: 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SSH host \(host.nickname), \(host.user) at \(host.hostname) port \(host.port)")
    }
}

/// The "+" button in the panel header. Local hover state so it brightens
/// on focus — the icon alone is otherwise too quiet to feel pressable.
private struct AddHostButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovered
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered
                              ? HerminalDesign.Palette.surfaceOverlay
                              : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: HerminalDesign.Motion.fast), value: isHovered)
        .accessibilityLabel("Add SSH host")
        .accessibilityHint("Opens an inline form to save a new host")
    }
}

/// Add / edit form for a single SSH host. Validates via `SSHHost.validated`
/// on submit and surfaces the error inline rather than crashing.
struct SSHHostFormView: View {
    let existing: SSHHost?
    let onSubmit: (SSHHost) -> Void

    @State private var nickname: String
    @State private var hostname: String
    @State private var user: String
    @State private var portText: String
    @State private var errorMessage: String?

    init(existing: SSHHost?, onSubmit: @escaping (SSHHost) -> Void) {
        self.existing = existing
        self.onSubmit = onSubmit
        _nickname = State(initialValue: existing?.nickname ?? "")
        _hostname = State(initialValue: existing?.hostname ?? "")
        _user = State(initialValue: existing?.user ?? "")
        _portText = State(initialValue: String(existing?.port ?? 22))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.sm) {
            field("Nickname", text: $nickname, placeholder: "prod-web")
            field("Hostname", text: $hostname, placeholder: "web1.example.com")
            field("User", text: $user, placeholder: NSUserName())
            field("Port", text: $portText, placeholder: "22")
            if let errorMessage {
                Text(errorMessage)
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.statusError)
            }
            HStack {
                Spacer()
                Button(existing == nil ? "Add Host" : "Save") { submit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(hostname.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(HerminalDesign.Typography.body)
        }
    }

    private func submit() {
        let port = Int(portText) ?? 22
        do {
            var host = try SSHHost.validated(
                id: existing?.id ?? UUID(),
                nickname: nickname,
                hostname: hostname,
                user: user,
                port: port
            )
            // Preserve created_at on edit; bump updated_at.
            if let existing {
                host = SSHHost(
                    id: existing.id,
                    nickname: host.nickname,
                    hostname: host.hostname,
                    user: host.user,
                    port: host.port,
                    createdAt: existing.createdAt,
                    updatedAt: Date(),
                    lastConnectedAt: existing.lastConnectedAt
                )
            }
            errorMessage = nil
            onSubmit(host)
        } catch SSHHostError.emptyHostname {
            errorMessage = "Hostname is required."
        } catch SSHHostError.invalidPort(let port) {
            errorMessage = "Port \(port) is out of range (1-65535)."
        } catch {
            errorMessage = "Could not save: \(error)"
        }
    }
}

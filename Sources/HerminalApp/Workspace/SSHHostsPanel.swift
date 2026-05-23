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
            Spacer()
            switch mode {
            case .list:
                Text("\(hosts.count)")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                Button {
                    mode = .editing(nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(HerminalDesign.Palette.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add host")
            case .editing:
                Button("Cancel") { mode = .list }
                    .font(HerminalDesign.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
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
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(host.nickname)
                    .font(HerminalDesign.Typography.bodyEmphasis)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Spacer()
                Button("Connect") { onConnect(host) }
                    .font(HerminalDesign.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(HerminalDesign.Palette.accent)
            }
            Text("\(host.user)@\(host.hostname):\(host.port)")
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
            if let lastConnected = host.lastConnectedAt {
                Text("Last connected \(Self.relative(lastConnected))")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textTertiary)
            }
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(HerminalDesign.Palette.surfaceOverlay)
        )
        .contextMenu {
            Button("Edit") { mode = .editing(host) }
            Button("Delete", role: .destructive) { onDelete(host.id) }
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
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

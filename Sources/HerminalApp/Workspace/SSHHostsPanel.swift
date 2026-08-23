// SSHHostsPanel — left-sidebar SSH connection manager.
// Lists saved hosts; inline form for add/edit; emits onConnect when the user
// wants to launch a session (the actual spawn happens in M4-4).

import AppKit
import SwiftUI
import HerminalDB

struct SSHHostsPanel: View {
    static let rowActionControlSize = HerminalDesign.Geometry.minimumInteractiveControlSize
    static let headerControlSize = HerminalDesign.Geometry.compactInteractiveControlSize

    let hosts: [SSHHost]
    let storageIsDurable: Bool
    @ObservedObject var filterState: SidebarFilterState
    let importFeedback: SSHImportFeedback?
    let initialFocusRequestID: UUID?
    let onConnect: (SSHHost) -> Void
    let onSave: (SSHHost) -> Void
    let onDelete: (UUID) -> Void
    let onImportConfig: () -> Void
    let onDismissImportFeedback: () -> Void

    enum Mode: Equatable {
        case list
        case editing(SSHHost?) // nil = new host
    }

    enum EmptyActionID: Hashable {
        case importConfig
        case addHost
        case clearFilter
    }

    enum InitialFocusTarget: Equatable {
        case none
        case importConfig
        case filter
        case firstHost(UUID)
        case hostname
    }

    @State private var mode: Mode = .list
    @State private var pendingDelete: UUID?
    @State private var consumedInitialFocusRequestID: UUID?
    @State private var recoveryFilterFocusRequestID: UUID?

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
        PanelChrome.header("SSH HOSTS") {
            switch mode {
            case .list:
                Text(
                    SSHHostsFilterPolicy.countLabel(
                        visible: filteredHosts.count,
                        total: hosts.count,
                        isFiltering: isFiltering
                    )
                )
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .accessibilityLabel(
                        SSHHostsFilterPolicy.countAccessibilityLabel(
                            visible: filteredHosts.count,
                            total: hosts.count,
                            isFiltering: isFiltering
                        )
                    )
                AddHostButton {
                    filterState.sshReturnFocusHostID = nil
                    mode = .editing(nil)
                }
            case .editing:
                HeaderCancelButton(action: cancelEditing)
            }
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .list:
            listView
        case .editing(let existing):
            VStack(alignment: .leading, spacing: 0) {
                if let noticeText = Self.storageNoticeText(storageIsDurable: storageIsDurable) {
                    storageNotice(text: noticeText)
                        .padding(.horizontal, PanelChrome.rail)
                        .padding(.top, HerminalDesign.Spacing.sm)
                }

                SSHHostFormView(
                    existing: existing,
                    onSubmit: { saved in
                        filterState.prepareForSavedHost(saved)
                        onSave(saved)
                        mode = .list
                    },
                    onCancel: cancelEditing
                )
                .padding(HerminalDesign.Spacing.sm)
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var listView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let importFeedback {
                SSHImportFeedbackView(
                    feedback: importFeedback,
                    storageIsDurable: storageIsDurable,
                    // Empty panels already expose Import + Add Host below;
                    // avoid repeating the same recovery control in the notice.
                    showsRecoveryAction: !hosts.isEmpty,
                    onRecovery: handleRecovery,
                    onDismiss: onDismissImportFeedback
                )
                .padding(.horizontal, PanelChrome.rail)
                .padding(.top, HerminalDesign.Spacing.sm)
            }

            if let noticeText = Self.storageNoticeText(storageIsDurable: storageIsDurable) {
                storageNotice(text: noticeText)
                    .padding(.horizontal, PanelChrome.rail)
                    .padding(.top, HerminalDesign.Spacing.sm)
            }

            if hosts.isEmpty {
                if importFeedback?.isImporting == true {
                    PanelChrome.emptyState(
                        "Checking your SSH config",
                        "Importable hosts will appear here in a moment."
                    )
                } else {
                    PanelChrome.emptyState(
                        Self.emptyStateContent(storageIsDurable: storageIsDurable),
                        initiallyFocusedActionID: initialFocusTarget == .importConfig
                            ? .importConfig
                            : nil
                    ) { action in
                        switch action {
                        case .importConfig:
                            onImportConfig()
                        case .addHost:
                            filterState.sshReturnFocusHostID = nil
                            mode = .editing(nil)
                        case .clearFilter:
                            filterState.sshHostsQuery = ""
                        }
                    }
                    .onAppear(perform: consumeEmptyStateFocusRequest)
                }
            } else {
                SidebarFilterField(
                    query: $filterState.sshHostsQuery,
                    prompt: "Filter hosts",
                    accessibilityLabel: Self.filterAccessibilityLabel,
                    accessibilityHint: Self.filterAccessibilityHint,
                    clearAccessibilityLabel: "Clear SSH host filter",
                    requestsInitialFocus: initialFocusTarget == .filter,
                    focusRequestID: recoveryFilterFocusRequestID,
                    resultAnnouncement: SSHHostsFilterPolicy.resultAccessibilityAnnouncement(
                        visible: filteredHosts.count,
                        total: hosts.count,
                        isFiltering: isFiltering
                    ),
                    onFocusRequestApplied: consumeRecoveryFilterFocusRequest,
                    onInitialFocusApplied: consumeFilterFocusRequest
                )
                .padding(.horizontal, PanelChrome.rail)
                .padding(.top, HerminalDesign.Spacing.sm)

                if SSHHostsFilterPolicy.showsNoMatches(
                    total: hosts.count,
                    visible: filteredHosts.count,
                    query: filterState.sshHostsQuery
                ) {
                    PanelChrome.emptyState(Self.noMatchesContent) { action in
                        if action == .clearFilter {
                            clearFilterAndFocus()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                            ForEach(filteredHosts) { host in
                                hostRow(
                                    host,
                                    requestsInitialFocus: initialFocusTarget == .firstHost(host.id),
                                    onInitialFocusApplied: { consumeFocusRequest(for: host.id) }
                                )
                            }
                        }
                        .padding(HerminalDesign.Spacing.sm)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func storageNotice(text: String) -> some View {
        HStack(alignment: .top, spacing: HerminalDesign.Spacing.xs) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HerminalDesign.Palette.accent)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: HerminalDesign.Spacing.xxs) {
                Text("Temporary storage")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textPrimary)
                Text(text)
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.storageNoticeAccessibilityLabel(storageIsDurable: storageIsDurable) ?? text)
        }
        .padding(HerminalDesign.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(HerminalDesign.Palette.accent.opacity(0.24), lineWidth: 1)
        )
    }

    private func handleRecovery(_ action: SSHImportFeedback.RecoveryAction) {
        switch action {
        case .addHost:
            filterState.sshReturnFocusHostID = nil
            mode = .editing(nil)
        case .retry:
            onImportConfig()
        }
    }

    private var initialFocusTarget: InitialFocusTarget {
        Self.initialFocusTarget(
            mode: mode,
            hosts: hosts,
            isImporting: importFeedback?.isImporting == true,
            initialFocusRequestID: initialFocusRequestID,
            consumedInitialFocusRequestID: consumedInitialFocusRequestID,
            returnFocusHostID: filterState.sshReturnFocusHostID
        )
    }

    static func initialFocusTarget(
        mode: Mode,
        hosts: [SSHHost],
        isImporting: Bool,
        initialFocusRequestID: UUID?,
        consumedInitialFocusRequestID: UUID?,
        returnFocusHostID: UUID?
    ) -> InitialFocusTarget {
        guard !isImporting else { return .none }
        switch mode {
        case .editing:
            return .hostname
        case .list:
            if let returnFocusHostID,
               hosts.contains(where: { $0.id == returnFocusHostID }) {
                return .firstHost(returnFocusHostID)
            }
            guard let initialFocusRequestID,
                  initialFocusRequestID != consumedInitialFocusRequestID else {
                return .none
            }
            return hosts.isEmpty ? .importConfig : .filter
        }
    }

    private var filteredHosts: [SSHHost] {
        SSHHostsFilterPolicy.filtered(hosts, query: filterState.sshHostsQuery)
    }

    private var isFiltering: Bool {
        !hosts.isEmpty && SidebarFilterQuery.isActive(filterState.sshHostsQuery)
    }

    private func hostRow(
        _ host: SSHHost,
        requestsInitialFocus: Bool,
        onInitialFocusApplied: @escaping () -> Void
    ) -> some View {
        SSHHostRow(host: host,
                   requestsInitialFocus: requestsInitialFocus,
                   onConnect: { onConnect(host) },
                   onEdit: { beginEditing(host) },
                   onDelete: { onDelete(host.id) },
                   onInitialFocusApplied: onInitialFocusApplied)
    }

    private func beginEditing(_ host: SSHHost) {
        filterState.sshReturnFocusHostID = host.id
        mode = .editing(host)
    }

    private func cancelEditing() {
        mode = .list
    }

    private func clearFilterAndFocus() {
        filterState.sshHostsQuery = ""
        recoveryFilterFocusRequestID = UUID()
    }

    private func consumeRecoveryFilterFocusRequest(_ requestID: UUID) {
        recoveryFilterFocusRequestID = SidebarFilterFocusPolicy.remainingRequest(
            currentRequestID: recoveryFilterFocusRequestID,
            appliedRequestID: requestID
        )
    }

    private func consumeEmptyStateFocusRequest() {
        guard initialFocusTarget == .importConfig,
              let initialFocusRequestID else { return }
        DispatchQueue.main.async {
            consumedInitialFocusRequestID = initialFocusRequestID
        }
    }

    private func consumeFilterFocusRequest() {
        guard initialFocusTarget == .filter,
              let initialFocusRequestID else { return }
        consumedInitialFocusRequestID = initialFocusRequestID
    }

    private func consumeFocusRequest(for hostID: UUID) {
        if filterState.sshReturnFocusHostID == hostID {
            filterState.sshReturnFocusHostID = nil
        }
        if let initialFocusRequestID {
            consumedInitialFocusRequestID = initialFocusRequestID
        }
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static let filterAccessibilityLabel = "Filter SSH hosts"
    static let filterAccessibilityHint =
        "Filters saved hosts by nickname, hostname, user, or port"

    static let noMatchesContent = PanelChrome.EmptyStateContent(
        headline: "No matching SSH hosts",
        detail: "No saved hosts match this filter. Clear it to show every saved host.",
        actions: [
            PanelChrome.EmptyStateAction(
                id: EmptyActionID.clearFilter,
                title: "Clear Filter",
                systemImage: "xmark.circle",
                accessibilityLabel: "Clear SSH host filter",
                accessibilityHint: "Clears the filter and shows every saved SSH host",
                prominence: .primary
            )
        ]
    )

    static func storageNoticeText(storageIsDurable: Bool) -> String? {
        guard !storageIsDurable else { return nil }
        return "Saved hosts last until Herminal quits."
    }

    static func storageNoticeAccessibilityLabel(storageIsDurable: Bool) -> String? {
        guard let text = storageNoticeText(storageIsDurable: storageIsDurable) else { return nil }
        return "SSH host storage. \(text)"
    }

    static func emptyStateContent(
        storageIsDurable: Bool
    ) -> PanelChrome.EmptyStateContent<EmptyActionID> {
        PanelChrome.EmptyStateContent(
            headline: "No hosts yet",
            detail: "Save a host manually, or import your ~/.ssh/config.",
            actions: [
                PanelChrome.EmptyStateAction(
                    id: EmptyActionID.importConfig,
                    title: "Import ~/.ssh/config",
                    systemImage: "square.and.arrow.down",
                    accessibilityLabel: "Import SSH hosts from config",
                    accessibilityHint: "Imports concrete Host entries from your SSH config",
                    prominence: .primary
                ),
                PanelChrome.EmptyStateAction(
                    id: EmptyActionID.addHost,
                    title: "Add Host",
                    systemImage: "plus",
                    accessibilityLabel: "Add SSH host",
                    accessibilityHint: "Opens the inline form for a new saved host",
                    prominence: .secondary
                )
            ]
        )
    }
}

/// One row in the SSH host list. Owns the hover state so the highlight
/// is row-local — sibling rows don't redraw on hover.
private struct SSHHostRow: View {
    let host: SSHHost
    let requestsInitialFocus: Bool
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onInitialFocusApplied: () -> Void

    @State private var isHovered = false
    @FocusState private var isConnectFocused: Bool
    @FocusState private var isActionsFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool {
        isHovered || isConnectFocused || isActionsFocused
    }

    var body: some View {
        HStack(spacing: HerminalDesign.Spacing.xs) {
            Button(action: onConnect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(host.nickname)
                        .font(HerminalDesign.Typography.bodyEmphasis)
                        .foregroundStyle(HerminalDesign.Palette.textPrimary)
                    Text("\(host.user)@\(host.hostname):\(host.port)")
                        .font(HerminalDesign.Typography.caption)
                        .foregroundStyle(HerminalDesign.Palette.textTertiary)
                    if let lastConnected = host.lastConnectedAt {
                        Text("Last connected \(SSHHostsPanel.relative(lastConnected))")
                            .font(HerminalDesign.Typography.caption)
                            .foregroundStyle(HerminalDesign.Palette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($isConnectFocused)
            .accessibilityLabel(
                "Connect to SSH host \(host.nickname), \(host.user) at \(host.hostname) port \(host.port)"
            )
            .accessibilityHint("Press Return or Space to connect")

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        isActionsFocused
                            ? HerminalDesign.Palette.accent
                            : HerminalDesign.Palette.textSecondary
                    )
                    .frame(
                        width: SSHHostsPanel.rowActionControlSize,
                        height: SSHHostsPanel.rowActionControlSize
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                isActionsFocused
                                    ? HerminalDesign.Palette.surfaceOverlay
                                    : Color.clear
                            )
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .focused($isActionsFocused)
            .accessibilityLabel("Actions for SSH host \(host.nickname)")
            .accessibilityHint("Opens edit and delete actions")
        }
        .padding(.horizontal, HerminalDesign.Spacing.sm)
        .padding(.vertical, HerminalDesign.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .fill(isEmphasized
                      ? HerminalDesign.Palette.surfaceOverlay.opacity(1.3)
                      : HerminalDesign.Palette.surfaceOverlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HerminalDesign.Radius.sm)
                .strokeBorder(
                    isEmphasized ? HerminalDesign.Palette.accent.opacity(0.45)
                                 : Color.clear,
                    lineWidth: 1
                )
        )
        .onAppear {
            guard requestsInitialFocus else { return }
            DispatchQueue.main.async {
                isConnectFocused = true
                onInitialFocusApplied()
            }
        }
        .onHover { isHovered = $0 }
        .animation(
            SidebarInteractiveChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

/// The "+" button in the panel header. Local hover state so it brightens
/// on focus — the icon alone is otherwise too quiet to feel pressable.
private struct AddHostButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool {
        isHovered || isFocused
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEmphasized
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .frame(
                    width: SSHHostsPanel.headerControlSize,
                    height: SSHHostsPanel.headerControlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isEmphasized
                              ? HerminalDesign.Palette.surfaceOverlay
                              : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isFocused ? HerminalDesign.Palette.accent.opacity(0.55) : .clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .animation(
            SidebarInteractiveChrome.shouldAnimate(reduceMotion: reduceMotion)
                ? .easeOut(duration: HerminalDesign.Motion.fast)
                : nil,
            value: isEmphasized
        )
        .accessibilityLabel("Add SSH host")
        .accessibilityHint("Opens an inline form to save a new host")
    }
}

private struct HeaderCancelButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmphasized: Bool {
        isHovered || isFocused
    }

    var body: some View {
        Button("Cancel", action: action)
            .font(HerminalDesign.Typography.caption)
            .buttonStyle(.plain)
            .foregroundStyle(
                isEmphasized
                    ? HerminalDesign.Palette.textPrimary
                    : HerminalDesign.Palette.textSecondary
            )
            .padding(.horizontal, HerminalDesign.Spacing.xs)
            .frame(minHeight: SSHHostsPanel.headerControlSize)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isEmphasized ? HerminalDesign.Palette.surfaceOverlay : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isFocused ? HerminalDesign.Palette.accent.opacity(0.55) : .clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .animation(
                SidebarInteractiveChrome.shouldAnimate(reduceMotion: reduceMotion)
                    ? .easeOut(duration: HerminalDesign.Motion.fast)
                    : nil,
                value: isEmphasized
            )
            .accessibilityLabel("Cancel host editing")
            .accessibilityHint("Returns to the saved hosts list")
    }
}

/// Add / edit form for a single SSH host. Validates via `SSHHost.validated`
/// on submit and surfaces the error inline rather than crashing.
struct SSHHostFormView: View {
    let existing: SSHHost?
    let onSubmit: (SSHHost) -> Void
    let onCancel: () -> Void

    enum Field: Hashable {
        case nickname
        case hostname
        case user
        case port

        var accessibilityLabel: String {
            switch self {
            case .nickname: "Nickname"
            case .hostname: "Hostname"
            case .user: "User"
            case .port: "Port"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .nickname: "Optional display name for this saved host"
            case .hostname: "Required server hostname or IP address"
            case .user: "Optional SSH user; defaults to the current macOS user"
            case .port: "SSH port from 1 through 65535"
            }
        }
    }

    struct ValidationPresentation: Equatable {
        let message: String
        let focusedField: Field?
    }

    enum FormValidationError: Error, Equatable {
        case invalidPortText
    }

    @State private var nickname: String
    @State private var hostname: String
    @State private var user: String
    @State private var portText: String
    @State private var errorMessage: String?
    @State private var errorField: Field?
    @FocusState private var focusedField: Field?

    init(
        existing: SSHHost?,
        onSubmit: @escaping (SSHHost) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.existing = existing
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _nickname = State(initialValue: existing?.nickname ?? "")
        _hostname = State(initialValue: existing?.hostname ?? "")
        _user = State(initialValue: existing?.user ?? "")
        _portText = State(initialValue: String(existing?.port ?? 22))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HerminalDesign.Spacing.sm) {
            field("Nickname", text: $nickname, placeholder: "prod-web", focus: .nickname)
            field("Hostname", text: $hostname, placeholder: "web1.example.com", focus: .hostname)
            field("User", text: $user, placeholder: NSUserName(), focus: .user)
            field("Port", text: $portText, placeholder: "22", focus: .port)
            if let errorMessage {
                Text("Error: \(errorMessage)")
                    .font(HerminalDesign.Typography.caption)
                    .foregroundStyle(HerminalDesign.Palette.statusError)
                    .accessibilityAddTraits(.isStaticText)
            }
            HStack {
                Spacer()
                Button(existing == nil ? "Add Host" : "Save") { submit() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!Self.canSubmit(hostname: hostname))
            }
        }
        .onAppear {
            DispatchQueue.main.async { focusedField = .hostname }
        }
        .onExitCommand { _ = Self.handleEscape(onCancel: onCancel) }
    }

    nonisolated static func canSubmit(hostname: String) -> Bool {
        !hostname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func handleEscape(onCancel: () -> Void) -> KeyPress.Result {
        onCancel()
        return .handled
    }

    static func validationPresentation(for error: Error) -> ValidationPresentation {
        switch error {
        case SSHHostError.emptyHostname:
            return ValidationPresentation(
                message: "Hostname is required.",
                focusedField: .hostname
            )
        case SSHHostError.invalidPort(let port):
            return ValidationPresentation(
                message: "Port \(port) is out of range (1-65535).",
                focusedField: .port
            )
        case FormValidationError.invalidPortText:
            return ValidationPresentation(
                message: "Port must be a number from 1 to 65535.",
                focusedField: .port
            )
        default:
            return ValidationPresentation(
                message: "Could not save: \(error.localizedDescription)",
                focusedField: nil
            )
        }
    }

    static func parsedPort(_ input: String) throws -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 22 }
        guard let port = Int(trimmed) else {
            throw FormValidationError.invalidPortText
        }
        return port
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        focus: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(HerminalDesign.Typography.caption)
                .foregroundStyle(HerminalDesign.Palette.textTertiary)
                .accessibilityHidden(true)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(HerminalDesign.Typography.body)
                .focused($focusedField, equals: focus)
                .accessibilityLabel(focus.accessibilityLabel)
                .accessibilityHint(accessibilityHint(for: focus))
                .onSubmit(submit)
                .onKeyPress(.escape) {
                    Self.handleEscape(onCancel: onCancel)
                }
        }
    }

    private func accessibilityHint(for field: Field) -> String {
        if errorField == field, let errorMessage {
            return errorMessage
        }
        return field.accessibilityHint
    }

    private func submit() {
        do {
            let port = try Self.parsedPort(portText)
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
            errorField = nil
            onSubmit(host)
        } catch {
            presentValidationError(Self.validationPresentation(for: error))
        }
    }

    private func presentValidationError(_ presentation: ValidationPresentation) {
        errorMessage = presentation.message
        errorField = presentation.focusedField
        focusedField = presentation.focusedField
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: presentation.message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}

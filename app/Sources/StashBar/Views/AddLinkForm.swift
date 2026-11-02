import SwiftUI

/// "Add a link" — used inside the popover and as a sheet over the canvas.
struct AddLinkForm: View {
    var prefill: String = ""
    var compact = false
    var onCancel: () -> Void
    var onDone: () -> Void

    @ObservedObject private var store = Store.shared
    @ObservedObject private var prefs = Prefs.shared
    @State private var text = ""
    @State private var title: String?
    @State private var fetching = false
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var fetchTask: Task<Void, Never>?
    @FocusState private var urlFocused: Bool

    private var parsed: CleanedLink? {
        LinkCleaner.parse(text, trackers: prefs.trackerList, strip: prefs.stripTrackers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("Add a link").heading(28).foregroundColor(Tok.text)
                Spacer()
                Button(action: onCancel) {
                    Icon(name: "x", size: 14)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close (Esc)")
                .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "URL")
                HStack(spacing: 10) {
                    Icon(name: "link", size: 15)
                    TextField("", text: $text, prompt: Text("Paste or type a web address").foregroundColor(Tok.muted))
                        .textFieldStyle(.plain)
                        .font(13)
                        .foregroundColor(Tok.text)
                        .focused($urlFocused)
                        .onSubmit(save)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(text.isEmpty || parsed != nil ? Tok.text : Tok.muted, lineWidth: 1))
                if let p = parsed, !p.removed.isEmpty {
                    HStack(spacing: 6) {
                        Icon(name: "shield-check", size: 13, color: Tok.muted)
                        Text("\(p.removed.count) tracker\(p.removed.count == 1 ? "" : "s") will be removed: \(p.removed.joined(separator: ", "))")
                            .font(12).foregroundColor(Tok.muted).lineLimit(1)
                    }
                } else if !text.isEmpty && parsed == nil {
                    Text("That doesn’t look like a web address yet.").font(12).foregroundColor(Tok.muted)
                }
            }

            if let p = parsed {
                HStack(spacing: 12) {
                    Icon(name: SiteLogo.icon(for: p.domain), size: 18)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.bg))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title ?? p.guessedTitle).font(13).foregroundColor(Tok.text).lineLimit(2)
                        Text(p.domain + (fetching ? " · fetching title…" : (title != nil ? " · title fetched" : "")))
                            .font(12).foregroundColor(Tok.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.card).fill(Tok.surface))
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Tags")
                FlowTags(selected: $tags, suggestions: store.tags.map { $0.0 }, newTag: $newTag)
            }

            HStack(spacing: 10) {
                Button("Cancel", action: onCancel).buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                Button(action: save) {
                    HStack(spacing: 8) { PinMark(size: 15, color: Palette.ink); Text("Stash it") }
                }
                .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
                .disabled(parsed == nil)
                .opacity(parsed == nil ? 0.5 : 1)
            }
            .padding(.top, 4)
        }
        .onAppear {
            text = prefill
            urlFocused = true
            fetchTitle()
        }
        .onChange(of: text) { _ in fetchTitle() }
        .onDisappear { fetchTask?.cancel() }
    }

    private func fetchTitle() {
        fetchTask?.cancel()
        title = nil
        guard let p = parsed else { fetching = false; return }
        fetching = true
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            let meta = await PageMeta.fetch(p.url)
            if Task.isCancelled { return }
            await MainActor.run {
                title = meta.title
                fetching = false
            }
        }
    }

    private func save() {
        guard let p = parsed else { return }
        var allTags = tags
        let t = Store.normalizeTag(newTag)
        if !t.isEmpty && !allTags.contains(t) { allTags.append(t) }
        store.stash(p, title: title, tags: allTags)
        onDone()
    }
}

/// Tag chips: selected ones in ink, suggestions outlined, plus a "+ Tag" field.
struct FlowTags: View {
    @Binding var selected: [String]
    var suggestions: [String]
    @Binding var newTag: String

    var body: some View {
        let all = Array(NSOrderedSet(array: selected + suggestions.prefix(6))) as? [String] ?? selected
        WrapLayout(spacing: 6) {
            ForEach(all, id: \.self) { t in
                let on = selected.contains(t)
                Button {
                    if on { selected.removeAll { $0 == t } } else { selected.append(t) }
                } label: {
                    Text(t).font(13, on ? .medium : .regular)
                        .foregroundColor(on ? .white : Tok.text)
                        .padding(.horizontal, 12).frame(height: 28)
                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(on ? Palette.charcoal : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(on ? Color.clear : Tok.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                Icon(name: "plus", size: 12, color: Tok.muted)
                TextField("", text: $newTag, prompt: Text("Tag").foregroundColor(Tok.muted))
                    .textFieldStyle(.plain).font(13).frame(width: 70)
                    .onSubmit {
                        let t = Store.normalizeTag(newTag)
                        if !t.isEmpty && !selected.contains(t) { selected.append(t) }
                        newTag = ""
                    }
            }
            .padding(.horizontal, 10).frame(height: 28)
            .overlay(RoundedRectangle(cornerRadius: Radius.control)
                .strokeBorder(Palette.mutedOnDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        }
    }
}

/// Simple flow layout (macOS 13 Layout protocol).
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            maxX = max(maxX, x)
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

import SwiftUI

/// 3y — opens when you click a card.
struct LinkDetailView: View {
    let link: Link
    @ObservedObject var nav: CanvasNav
    @ObservedObject private var store = Store.shared
    @ObservedObject private var prefs = Prefs.shared
    @State private var note = ""
    @State private var title = ""
    @State private var newTag = ""
    @State private var preview: NSImage?
    @State private var editingTitle = false

    var body: some View {
        HStack(spacing: 0) {
            // Preview side
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { nav.detailID = nil } label: {
                        HStack(spacing: 6) { Icon(name: "arrow-left", size: 14); Text(nav.view.title).font(13, .medium) }
                            .foregroundColor(Tok.text)
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.bg))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .help("Back (Esc)")
                    Spacer()
                }
                .padding(.leading, 18)
                .padding(.top, 40)
                .padding(.bottom, 14)

                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: Radius.card).fill(Palette.charcoal)
                    if prefs.linkPreviews, let preview {
                        Image(nsImage: preview).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.control))
                            .padding(28)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Icon(name: SiteLogo.icon(for: link.domain), size: 64, color: .white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    Text("page preview · \(link.domain)").font(12).foregroundColor(Palette.mutedOnDark)
                        .padding(.leading, 18).padding(.bottom, 16)
                }
                .padding([.horizontal, .bottom], 18)
            }
            .frame(maxWidth: .infinity)
            .background(Tok.surface)

            // Detail panel
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        SectionLabel(text: "Link detail")
                        Spacer()
                        IconButton(icon: "pin", size: 32, iconSize: 14, help: link.pinned ? "Unpin (⌘P)" : "Pin to top (⌘P)",
                                   filled: link.pinned) { store.togglePin(link.id) }
                            .keyboardShortcut("p", modifiers: .command)
                        IconButton(icon: link.archived ? "archive-restore" : "archive", size: 32, iconSize: 14,
                                   help: link.archived ? "Restore" : "Archive (⌫)") {
                            if link.archived { store.restore(link.id) } else { store.archive(link.id); nav.detailID = nil }
                        }
                        IconButton(icon: "trash-2", size: 32, iconSize: 14, help: "Delete") { nav.confirmDeleteID = link.id }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if editingTitle {
                            TextField("Title", text: $title, axis: .vertical)
                                .textFieldStyle(.plain).heading(28).foregroundColor(Tok.text)
                                .onSubmit { commitTitle() }
                        } else {
                            Text(link.title).heading(28).foregroundColor(Tok.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture(count: 2) { title = link.title; editingTitle = true }
                                .help("Double-click to rename")
                        }
                        HStack(spacing: 8) {
                            Icon(name: SiteLogo.icon(for: link.domain), size: 14, color: Tok.muted)
                            Text("\(link.domain) · stashed \(RelativeTime.long(link.createdAt))").font(13).foregroundColor(Tok.muted)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionLabel(text: "Clean URL")
                            Spacer()
                            if !link.trackersRemoved.isEmpty {
                                HStack(spacing: 5) {
                                    Icon(name: "shield-check", size: 12, color: Tok.muted)
                                    SectionLabel(text: "\(link.trackersRemoved.count) tracker\(link.trackersRemoved.count == 1 ? "" : "s") removed")
                                }
                            }
                        }
                        Text(link.url).font(13).foregroundColor(Tok.text).textSelection(.enabled)
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.bg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Tok.line, lineWidth: 1))
                        if !link.trackersRemoved.isEmpty {
                            WrapLayout(spacing: 6) {
                                ForEach(link.trackersRemoved, id: \.self) { t in
                                    Text(t).font(12).foregroundColor(Tok.muted).strikethrough()
                                        .padding(.horizontal, 9).frame(height: 24)
                                        .background(RoundedRectangle(cornerRadius: Radius.control).fill(Tok.surface))
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Tags")
                        WrapLayout(spacing: 6) {
                            ForEach(link.tags, id: \.self) { t in
                                Button { store.removeTag(link.id, t) } label: {
                                    HStack(spacing: 6) {
                                        Text(t).font(13, .medium)
                                        Icon(name: "x", size: 10, color: .white).opacity(0.6)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12).frame(height: 28)
                                    .background(RoundedRectangle(cornerRadius: Radius.control).fill(Palette.charcoal))
                                }
                                .buttonStyle(.plain)
                                .help("Remove tag")
                            }
                            HStack(spacing: 4) {
                                Icon(name: "plus", size: 12, color: Tok.muted)
                                TextField("", text: $newTag, prompt: Text("Tag").foregroundColor(Tok.muted))
                                    .textFieldStyle(.plain).font(13).frame(width: 70)
                                    .onSubmit { store.addTag(link.id, newTag); newTag = "" }
                            }
                            .padding(.horizontal, 12).frame(height: 28)
                            .overlay(RoundedRectangle(cornerRadius: Radius.control)
                                .strokeBorder(Palette.mutedOnDark, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Note")
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Add a note…").font(13).foregroundColor(Tok.muted).padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            TextEditor(text: $note)
                                .font(Fonts.ui(13))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 9).padding(.vertical, 8)
                                .frame(minHeight: 80)
                        }
                        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Tok.line, lineWidth: 1))
                    }

                    HStack(spacing: 10) {
                        Button { store.copy(link) } label: {
                            HStack(spacing: 8) { Icon(name: "copy", size: 15, color: Palette.ink); Text("Copy link") }
                        }
                        .buttonStyle(PrimaryButtonStyle(height: 46, fullWidth: true))
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                        Button { store.open(link) } label: {
                            HStack(spacing: 8) { Icon(name: "arrow-up-right", size: 15); Text("Open") }
                        }
                        .buttonStyle(OutlineButtonStyle(height: 46, fullWidth: true))
                        .keyboardShortcut("o", modifiers: .command)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 26)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .frame(width: 400)
            .background(Tok.bg)
        }
        .onAppear { note = link.note; title = link.title }
        .onChange(of: link.id) { _ in note = link.note; title = link.title; editingTitle = false }
        .onChange(of: note) { v in
            if v != link.note { store.update(link.id) { $0.note = v } }
        }
        .task(id: link.previewImageURL) {
            if prefs.linkPreviews, let u = link.previewImageURL { preview = await PreviewCache.image(for: u) } else { preview = nil }
        }
    }

    private func commitTitle() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty && t != link.title { store.update(link.id) { $0.title = t } }
        editingTitle = false
    }
}

//
//  AriaDocumentsScreen.swift
//  Apprentice
//
//  Redesigned Documents (aria-redesign.html #v-docs): connected data-room source
//  + recent uploads, wired to SafeDocumentManager / StitchDataRoomSource.
//

import SwiftUI
import UniformTypeIdentifiers

struct AriaDocumentsScreen: View {
    @StateObject private var docs = SafeDocumentManager()
    @State private var syncing = false
    @State private var importing = false
    @State private var message: String?

    private var indexing: Bool { docs.processingProgress > 0 && docs.processingProgress < 1 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AriaEyebrow(text: "Knowledge base").padding(.top, 14).padding(.bottom, 10)
                AriaTitle(plain: "Your ", em: "documents")
                AriaSub(text: "Everything Aria can reference in a meeting.")
                    .padding(.top, 6).padding(.bottom, 24)

                sourceCard.padding(.bottom, indexing ? 18 : 24)
                if indexing { progress.padding(.bottom, 26) }
                if let message { banner(message).padding(.bottom, 20) }

                HStack {
                    AriaSectionLabel(text: "Recent uploads")
                    Spacer()
                    Button { importing = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                            Text("Add").font(.inter(12, .medium))
                        }.foregroundColor(Aria.gold)
                    }
                }
                .padding(.bottom, 14)

                if docs.documents.isEmpty {
                    emptyState
                } else {
                    ForEach(docs.documents.reversed()) { doc in
                        docRow(doc).padding(.bottom, 11)
                    }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 40)
        }
        .background(AriaBackground())
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .plainText, .rtf, .commaSeparatedText, .data], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { importFile(url) }
        }
    }

    private var sourceCard: some View {
        Button { syncDataRoom() } label: {
            HStack(spacing: 16) {
                Image(systemName: "building.columns")
                    .font(.system(size: 22)).foregroundColor(Color(red: 0.16, green: 0.06, blue: 0.04))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(RadialGradient(colors: [Aria.rose, Color(red: 0.48, green: 0.29, blue: 0.24)], center: UnitPoint(x: 0.3, y: 0.3), startRadius: 2, endRadius: 50)))
                    .shadow(color: Aria.rose.opacity(0.6), radius: 10, y: 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Investor Data Room").font(.fraunces(18, .medium)).foregroundColor(Aria.ivory)
                    Text(syncing ? "Syncing — pulling documents into memory…" : "Connected · tap to sync into Aria's memory")
                        .font(.inter(12.5)).foregroundColor(Aria.ivoryDim).lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18)).foregroundColor(Aria.rose)
                    .rotationEffect(.degrees(syncing ? 360 : 0))
                    .animation(syncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncing)
            }
            .padding(20)
            .background(LinearGradient(colors: [Aria.rose.opacity(0.1), Aria.panel.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Aria.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(syncing)
    }

    private var progress: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Aria.panel2).frame(height: 5)
                    Capsule().fill(LinearGradient(colors: [Aria.gold, Aria.goldBright], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * docs.processingProgress, height: 5)
                }
            }
            .frame(height: 5)
            HStack {
                Text("Indexing documents").font(.ariaMono(11.5)).foregroundColor(Aria.ivoryDim)
                Spacer()
                Text("\(Int(docs.processingProgress * 100))%").font(.ariaMono(11.5)).foregroundColor(Aria.ivoryDim)
            }
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text).font(.inter(12.5)).foregroundColor(Aria.jade)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(Aria.jade.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func docRow(_ doc: ProcessedDocument) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text").font(.system(size: 18)).foregroundColor(Aria.gold)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12).fill(Aria.gold.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title).font(.inter(14.5, .semibold)).foregroundColor(Aria.ivory).lineLimit(1)
                Text("\(sizeText(doc.fileSize)) · \(doc.uploadDate.formatted(date: .numeric, time: .omitted))")
                    .font(.ariaMono(11.5)).foregroundColor(Aria.ivoryFaint)
            }
            Spacer()
            if doc.isAnalyzed {
                HStack(spacing: 6) {
                    Circle().fill(Aria.jade).frame(width: 6, height: 6).shadow(color: Aria.jade, radius: 4)
                    Text("Analyzed").font(.inter(11)).foregroundColor(Aria.jade)
                }
            }
        }
        .padding(15).background(Aria.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Aria.lineSoft, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder").font(.system(size: 26)).foregroundColor(Aria.gold)
            Text("No documents yet").font(.fraunces(18, .medium)).foregroundColor(Aria.ivory)
            Text("Sync the data room or add a file — Aria reads them into memory.")
                .font(.inter(13)).foregroundColor(Aria.ivoryFaint).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Aria.line))
    }

    // MARK: Actions

    private func syncDataRoom() {
        guard !syncing else { return }
        syncing = true; message = nil
        Task {
            do {
                let n = try await docs.syncSource(StitchDataRoomSource())
                message = "Synced \(n) document\(n == 1 ? "" : "s") from the data room."
            } catch {
                message = "Sync failed: \(error.localizedDescription)"
            }
            syncing = false
        }
    }

    private func importFile(_ url: URL) {
        Task {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do { _ = try await docs.processDocument(url: url); message = "Added \(url.lastPathComponent)." }
            catch { message = "Couldn't add that file: \(error.localizedDescription)" }
        }
    }

    private func sizeText(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return "\(max(1, Int(Double(bytes) / 1024))) KB"
    }
}

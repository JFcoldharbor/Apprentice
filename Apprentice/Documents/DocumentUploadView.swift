//
//  DocumentUploadView.swift
//  Apprentice
//
//  Layer 8: Views - Document upload interface
//  FIXED: Corrected SafeDocumentManager integration
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ExecutiveSession Hashable Extension

extension ExecutiveSession: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ExecutiveSession, rhs: ExecutiveSession) -> Bool {
        return lhs.id == rhs.id
    }
}

struct DocumentUploadView: View {
    
    // MARK: - Dependencies - FIXED to use SafeDocumentManager properly
    
    @StateObject private var safeDocumentManager = SafeDocumentManager()
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var showingFilePicker = false
    @State private var showingPhotosPicker = false
    @State private var selectedSession: ExecutiveSession?
    @State private var uploadedDocuments: [ProcessedDocument] = []
    @State private var showingUploadProgress = false
    @State private var customTitle = ""
    @State private var errorMessage: String?
    @State private var isSyncingDataRoom = false
    @State private var dataRoomSyncMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        uploadOptionsSection
                        connectedSourcesSection
                        settingsSection
                        if !uploadedDocuments.isEmpty {
                            recentUploadsSection
                        }
                        if let error = errorMessage {
                            errorSection(error)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Upload Documents")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .image, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        handleDocumentUpload(url)
                    }
                case .failure(let error):
                    errorMessage = "File picker error: \(error.localizedDescription)"
                }
            }
        }
        .onAppear {
            loadRecentUploads()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // AI Icon and Title
            HStack(spacing: 16) {
                Circle()
                    .fill(.cyan)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.text.image")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Document Intelligence")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Upload documents for AI-powered analysis")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Upload Options Section
    
    private var uploadOptionsSection: some View {
        VStack(spacing: 16) {
            Text("Choose Upload Method")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                UploadOptionCard(
                    title: "Files",
                    subtitle: "PDF, Text, Documents",
                    icon: "doc.text",
                    color: .cyan
                ) {
                    showingFilePicker = true
                }
                
                UploadOptionCard(
                    title: "Photos",
                    subtitle: "Scan documents",
                    icon: "camera",
                    color: .green
                ) {
                    showingPhotosPicker = true
                }
            }
        }
    }
    
    // MARK: - Connected Sources Section

    private var connectedSourcesSection: some View {
        VStack(spacing: 16) {
            Text("Connected Sources")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                syncDataRoom()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 26))
                        .foregroundColor(.purple)
                        .frame(width: 48, height: 48)
                        .background(.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Investor Data Room")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(isSyncingDataRoom
                             ? "Syncing… \(Int(safeDocumentManager.processingProgress * 100))%"
                             : "Pull every document into Aria's memory")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    if isSyncingDataRoom {
                        ProgressView()
                            .tint(.purple)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.purple)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.purple.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSyncingDataRoom)

            if let message = dataRoomSyncMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(spacing: 16) {
            Text("Document Settings")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                // Custom Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Title (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Enter custom title", text: $customTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .background(.white.opacity(0.1))
                        .foregroundColor(.white)
                }
                
                // Session Association
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associate with Session")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Picker("Select Session", selection: $selectedSession) {
                        Text("None").tag(nil as ExecutiveSession?)
                        ForEach(sessionManager.sessions.prefix(10), id: \.id) { session in
                            Text(session.title).tag(session as ExecutiveSession?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.cyan)
                }
            }
            .padding(20)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Recent Uploads Section
    
    private var recentUploadsSection: some View {
        VStack(spacing: 16) {
            Text("Recent Uploads")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 12) {
                ForEach(uploadedDocuments.prefix(5)) { document in
                    SimpleUploadedDocumentCard(document: document)
                }
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
                Button("Dismiss") {
                    errorMessage = nil
                }
                .foregroundColor(.cyan)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.02, blue: 0.08),
                Color(red: 0.05, green: 0.08, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Document Upload Handler - FIXED for SafeDocumentManager
    
    private func handleDocumentUpload(_ url: URL) {
        showingUploadProgress = true
        errorMessage = nil
        
        Task {
            do {
                let title = customTitle.isEmpty ? url.deletingPathExtension().lastPathComponent : customTitle
                
                // FIXED: Use processDocument instead of addDocument
                let processedDocument = try await safeDocumentManager.processDocument(url: url)
                
                // Add to recent uploads for display
                await MainActor.run {
                    loadRecentUploads()
                    showingUploadProgress = false
                    customTitle = ""
                }
                
                print("✅ Document processed successfully: \(processedDocument.title)")
                
            } catch {
                await MainActor.run {
                    showingUploadProgress = false
                    errorMessage = "Failed to process document: \(error.localizedDescription)"
                }
                print("❌ Document processing failed: \(error)")
            }
        }
    }
    
    private func loadRecentUploads() {
        uploadedDocuments = Array(safeDocumentManager.documents.suffix(10))
    }

    // MARK: - Connected Source Sync (on-demand, no background polling)

    private func syncDataRoom() {
        guard !isSyncingDataRoom else { return }
        isSyncingDataRoom = true
        dataRoomSyncMessage = nil
        errorMessage = nil

        Task {
            do {
                let count = try await safeDocumentManager.syncSource(StitchDataRoomSource())
                await MainActor.run {
                    isSyncingDataRoom = false
                    dataRoomSyncMessage = count > 0
                        ? "Synced \(count) item\(count == 1 ? "" : "s") from the data room."
                        : "No documents came back from the data room."
                    loadRecentUploads()
                }
            } catch {
                await MainActor.run {
                    isSyncingDataRoom = false
                    errorMessage = "Data room sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Upload Option Card

struct UploadOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Simple Uploaded Document Card - FIXED ProcessedDocument reference

struct SimpleUploadedDocumentCard: View {
    let document: ProcessedDocument // FIXED: Removed SafeDocumentManager. prefix
    
    var body: some View {
        HStack(spacing: 12) {
            // Document Icon
            Image(systemName: iconForFileType(document.fileURL.pathExtension))
                .font(.title2)
                .foregroundColor(.cyan)
                .frame(width: 40, height: 40)
                .background(.cyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Document Info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(formatFileSize(document.fileSize)) • \(formatDate(document.uploadDate))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Status Indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(document.isAnalyzed ? .green : .orange)
                    .frame(width: 6, height: 6)
                
                Text(document.isAnalyzed ? "Analyzed" : "Processing")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(12)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func iconForFileType(_ fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "pdf": return "doc.text"
        case "jpg", "jpeg", "png", "heic": return "photo"
        case "txt": return "doc"
        default: return "doc"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    DocumentUploadView()
        .environmentObject(SessionManager.shared)
}

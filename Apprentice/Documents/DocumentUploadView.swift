//
//  DocumentUploadView.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  DocumentUploadView.swift
//  Stitch Executive AI
//
//  Layer 8: Views - Simple document upload interface
//  FIXED: Updated to use SafeDocumentManager and added ExecutiveSession Hashable conformance
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
    
    // MARK: - Dependencies - FIXED to use SafeDocumentManager
    
    @StateObject private var safeDocumentManager = SafeDocumentManager()
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var showingFilePicker = false
    @State private var showingPhotosPicker = false
    @State private var selectedSession: ExecutiveSession?
    @State private var uploadedDocuments: [SafeDocumentManager.ProcessedDocument] = []
    @State private var showingUploadProgress = false
    @State private var customTitle = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        uploadOptionsSection
                        settingsSection
                        if !uploadedDocuments.isEmpty {
                            recentUploadsSection
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
                    print("File picker error: \(error)")
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
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.cyan)
            
            Text("Add Business Documents")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Upload images, PDFs, and documents for AI analysis and business intelligence")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
                    title: "Camera",
                    subtitle: "Take photo",
                    icon: "camera",
                    color: .blue
                ) {
                    // Camera functionality - placeholder
                    print("Camera upload selected")
                }
                
                UploadOptionCard(
                    title: "Photo Library",
                    subtitle: "Choose images",
                    icon: "photo.on.rectangle",
                    color: .green
                ) {
                    showingPhotosPicker = true
                }
                
                UploadOptionCard(
                    title: "Files",
                    subtitle: "Browse documents",
                    icon: "folder",
                    color: .orange
                ) {
                    showingFilePicker = true
                }
                
                UploadOptionCard(
                    title: "Scan Document",
                    subtitle: "Camera scan",
                    icon: "doc.viewfinder",
                    color: .purple
                ) {
                    // Document scanner functionality - placeholder
                    print("Document scanner selected")
                }
            }
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 20) {
            Text("Upload Settings")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                // Custom Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Title (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Enter custom title", text: $customTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Session Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link to Session (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Picker("Session", selection: $selectedSession) {
                        Text("No Session").tag(nil as ExecutiveSession?)
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
        
        Task {
            // Use SafeDocumentManager's simple interface
            let title = customTitle.isEmpty ? nil : customTitle
            safeDocumentManager.addDocument(url: url, title: title)
            
            // Add to recent uploads for display
            await MainActor.run {
                loadRecentUploads()
                showingUploadProgress = false
                customTitle = ""
            }
        }
    }
    
    private func loadRecentUploads() {
        uploadedDocuments = Array(safeDocumentManager.documents.suffix(10))
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

// MARK: - Simple Uploaded Document Card

struct SimpleUploadedDocumentCard: View {
    let document: SafeDocumentManager.ProcessedDocument
    
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
                
                Text("\(formatFileSize(document.fileSize)) â€¢ \(formatDate(document.uploadDate))")
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
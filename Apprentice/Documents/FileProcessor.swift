//
//  FileProcessor.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  FileProcessor.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - File processing and validation utilities
//  Handles file validation, conversion, thumbnails, and optimization
//

import Foundation
import UIKit
import PDFKit
import QuickLook
import UniformTypeIdentifiers

class FileProcessor: FileProcessingProtocol {
    
    // MARK: - File Validation
    
    func validateFile(at url: URL) async throws -> Bool {
        print("ðŸ” [FILE] Validating file: \(url.lastPathComponent)")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentError.fileNotFound
        }
        
        // Check file extension
        let fileExtension = url.pathExtension.lowercased()
        guard Config.isFileFormatSupported(fileExtension) else {
            throw DocumentError.unsupportedFormat
        }
        
        // Check file size
        let fileSize = try await calculateFileSize(for: url)
        let sizeLimit = Config.getSizeLimit(for: fileExtension)
        guard fileSize <= sizeLimit else {
            throw DocumentError.fileTooLarge(maxSize: sizeLimit)
        }
        
        // Validate file content based on type
        if Config.Documents.supportedImageFormats.contains(fileExtension) {
            return try await validateImageFile(at: url)
        } else if fileExtension == "pdf" {
            return try await validatePDFFile(at: url)
        } else {
            return try await validateDocumentFile(at: url)
        }
    }
    
    func getFileMetadata(for url: URL) async throws -> DocumentMetadata {
        print("ðŸ“‹ [FILE] Extracting metadata for: \(url.lastPathComponent)")
        
        let resourceValues = try url.resourceValues(forKeys: [
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ])
        
        var pageCount: Int?
        var wordCount: Int?
        
        // Extract additional metadata based on file type
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "pdf" {
            if let pdfDocument = PDFDocument(url: url) {
                pageCount = pdfDocument.pageCount
                
                // Extract text for word count
                var fullText = ""
                for i in 0..<pdfDocument.pageCount {
                    if let page = pdfDocument.page(at: i), let pageText = page.string {
                        fullText += pageText + " "
                    }
                }
                wordCount = fullText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            }
        }
        
        return DocumentMetadata(
            creator: nil, // File owner not available on iOS
            creationDate: resourceValues.creationDate,
            lastModified: resourceValues.contentModificationDate,
            pageCount: pageCount,
            wordCount: wordCount,
            originalFileSize: Int64(resourceValues.fileSize ?? 0)
        )
    }
    
    func calculateFileSize(for url: URL) async throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
    
    // MARK: - File Conversion
    
    func convertToSupportedFormat(fileURL: URL) async throws -> URL {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Check if already supported
        if Config.isFileFormatSupported(fileExtension) {
            return fileURL
        }
        
        // Handle HEIC images
        if fileExtension == "heic" {
            return try await convertHEICToJPEG(fileURL)
        }
        
        // For other unsupported formats, throw error
        throw DocumentError.unsupportedFormat
    }
    
    func optimizeForVisionAPI(imageURL: URL) async throws -> URL {
        print("ðŸ”§ [FILE] Optimizing image for Vision API: \(imageURL.lastPathComponent)")
        
        guard let originalImage = UIImage(contentsOfFile: imageURL.path) else {
            throw DocumentError.processingFailed("Unable to load image")
        }
        
        // Resize if too large
        let maxDimension = Config.Vision.maxImageDimension
        let optimizedImage = originalImage.resized(toMaxDimension: maxDimension)
        
        // Create optimized file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        guard let jpegData = optimizedImage.jpegData(compressionQuality: Config.Vision.compressionQuality) else {
            throw DocumentError.processingFailed("Image compression failed")
        }
        
        try jpegData.write(to: tempURL)
        
        print("âœ… [FILE] Image optimized: \(originalImage.size) â†’ \(optimizedImage.size)")
        return tempURL
    }
    
    func createThumbnail(from fileURL: URL, size: CGSize) async throws -> URL {
        print("ðŸ–¼ï¸ [FILE] Creating thumbnail for: \(fileURL.lastPathComponent)")
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        if Config.Documents.supportedImageFormats.contains(fileExtension) {
            return try await createImageThumbnail(from: fileURL, size: size)
        } else if fileExtension == "pdf" {
            return try await createPDFThumbnail(from: fileURL, size: size)
        } else {
            return try await createDocumentThumbnail(from: fileURL, size: size)
        }
    }
    
    // MARK: - Storage Management
    
    func moveToDocumentsDirectory(_ sourceURL: URL, filename: String) async throws -> URL {
        let documentsURL = Config.documentStorageURL(for: Config.Documents.documentsDirectory)
        let destinationURL = documentsURL.appendingPathComponent(filename)
        
        // Ensure unique filename
        var finalURL = destinationURL
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let name = filename.replacingOccurrences(of: ".\(destinationURL.pathExtension)", with: "")
            let newFilename = "\(name)_\(counter).\(destinationURL.pathExtension)"
            finalURL = documentsURL.appendingPathComponent(newFilename)
            counter += 1
        }
        
        // Copy file to destination
        try FileManager.default.copyItem(at: sourceURL, to: finalURL)
        
        print("ðŸ“ [FILE] File moved to: \(finalURL.lastPathComponent)")
        return finalURL
    }
    
    func cleanupTemporaryFiles() async throws {
        let tempURL = Config.documentStorageURL(for: Config.Documents.tempDirectory)
        let tempFiles = try FileManager.default.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil)
        
        for tempFile in tempFiles {
            // Only delete files older than 1 hour
            let resourceValues = try tempFile.resourceValues(forKeys: [.contentModificationDateKey])
            if let modificationDate = resourceValues.contentModificationDate,
               Date().timeIntervalSince(modificationDate) > 3600 {
                try FileManager.default.removeItem(at: tempFile)
            }
        }
        
        print("ðŸ§¹ [FILE] Temporary files cleaned up")
    }
    
    func getStorageUsage() async throws -> Int64 {
        let documentsURL = Config.documentStorageURL(for: Config.Documents.documentsDirectory)
        return try await calculateDirectorySize(documentsURL)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateImageFile(at url: URL) async throws -> Bool {
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw DocumentError.processingFailed("Invalid image file")
        }
        
        // Check minimum resolution
        let minResolution = Config.Processing.minimumImageResolution
        guard image.size.width >= minResolution && image.size.height >= minResolution else {
            throw DocumentError.processingFailed("Image resolution too low")
        }
        
        return true
    }
    
    private func validatePDFFile(at url: URL) async throws -> Bool {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentError.processingFailed("Invalid PDF file")
        }
        
        guard pdfDocument.pageCount > 0 else {
            throw DocumentError.processingFailed("PDF has no pages")
        }
        
        return true
    }
    
    private func validateDocumentFile(at url: URL) async throws -> Bool {
        // Basic validation - check if file is readable
        do {
            _ = try Data(contentsOf: url)
            return true
        } catch {
            throw DocumentError.processingFailed("Unable to read document file")
        }
    }
    
    // MARK: - Private Conversion Methods
    
    private func convertHEICToJPEG(_ heicURL: URL) async throws -> URL {
        guard let heicImage = UIImage(contentsOfFile: heicURL.path) else {
            throw DocumentError.processingFailed("Unable to load HEIC image")
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(heicURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("jpg")
        
        guard let jpegData = heicImage.jpegData(compressionQuality: Config.Documents.compressionQuality) else {
            throw DocumentError.processingFailed("HEIC to JPEG conversion failed")
        }
        
        try jpegData.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - Private Thumbnail Methods
    
    private func createImageThumbnail(from imageURL: URL, size: CGSize) async throws -> URL {
        guard let originalImage = UIImage(contentsOfFile: imageURL.path) else {
            throw DocumentError.processingFailed("Unable to load image for thumbnail")
        }
        
        let thumbnailImage = originalImage.resized(toFit: size)
        
        let thumbnailsURL = Config.documentStorageURL(for: Config.Documents.thumbnailsDirectory)
        let thumbnailURL = thumbnailsURL.appendingPathComponent("\(UUID().uuidString).jpg")
        
        guard let jpegData = thumbnailImage.jpegData(compressionQuality: 0.8) else {
            throw DocumentError.processingFailed("Thumbnail creation failed")
        }
        
        try jpegData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func createPDFThumbnail(from pdfURL: URL, size: CGSize) async throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL),
              let firstPage = pdfDocument.page(at: 0) else {
            throw DocumentError.processingFailed("Unable to read PDF for thumbnail")
        }
        
        let pageRect = firstPage.bounds(for: .mediaBox)
        let thumbnail = firstPage.thumbnail(of: size, for: .mediaBox)
        
        let thumbnailsURL = Config.documentStorageURL(for: Config.Documents.thumbnailsDirectory)
        let thumbnailURL = thumbnailsURL.appendingPathComponent("\(UUID().uuidString).png")
        
        guard let pngData = thumbnail.pngData() else {
            throw DocumentError.processingFailed("PDF thumbnail creation failed")
        }
        
        try pngData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func createDocumentThumbnail(from documentURL: URL, size: CGSize) async throws -> URL {
        // For non-image/PDF documents, create a generic thumbnail with file type icon
        let fileExtension = documentURL.pathExtension.lowercased()
        let documentType = BusinessDocument.DocumentType.from(fileExtension: fileExtension)
        
        let thumbnailImage = createGenericThumbnail(for: documentType, size: size)
        
        let thumbnailsURL = Config.documentStorageURL(for: Config.Documents.thumbnailsDirectory)
        let thumbnailURL = thumbnailsURL.appendingPathComponent("\(UUID().uuidString).png")
        
        guard let pngData = thumbnailImage.pngData() else {
            throw DocumentError.processingFailed("Generic thumbnail creation failed")
        }
        
        try pngData.write(to: thumbnailURL)
        return thumbnailURL
    }
    
    private func createGenericThumbnail(for documentType: BusinessDocument.DocumentType, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Border
            UIColor.systemGray3.setStroke()
            let borderRect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            let borderPath = UIBezierPath(rect: borderRect)
            borderPath.lineWidth = 2
            borderPath.stroke()
            
            // Icon
            let iconSize: CGFloat = min(size.width, size.height) * 0.5
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            if let iconImage = UIImage(systemName: documentType.icon)?.withRenderingMode(.alwaysTemplate) {
                UIColor.systemBlue.setFill()
                iconImage.draw(in: iconRect)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateDirectorySize(_ directoryURL: URL) async throws -> Int64 {
        var totalSize: Int64 = 0
        
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: resourceKeys,
            options: .skipsHiddenFiles
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isDirectory == false {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
}

// MARK: - UIImage Extensions

private extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        
        if ratio >= 1 {
            return self
        }
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return resized(to: newSize)
    }
    
    func resized(toFit targetSize: CGSize) -> UIImage {
        let aspectRatio = size.width / size.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var newSize = targetSize
        
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize.height = targetSize.width / aspectRatio
        } else {
            // Image is taller than target
            newSize.width = targetSize.height * aspectRatio
        }
        
        return resized(to: newSize)
    }
    
    func resized(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
}
//
//  EmailService.swift
//  Apprentice
//
//  Created by James Garmon on 8/26/25.
//


//
//  EmailService.swift
//  Stitch Executive AI
//
//  Layer 4: Core Services - Email integration and template management
//  COMPLETE VERSION - Matches all view implementations
//

import Foundation
import MessageUI
import SwiftUI

@MainActor
class EmailService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var canSendEmail = false
    @Published var isComposingEmail = false
    @Published var lastEmailError: String?
    
    // MARK: - Email Configuration
    
    private struct EmailConfig {
        static let defaultSubjectPrefix = "Session Summary"
        static let senderSignature = "Sent via Stitch Executive AI"
        static let defaultRecipients: [String] = []
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        updateEmailCapability()
    }
    
    // MARK: - Email Capability Detection
    
    func updateEmailCapability() {
        canSendEmail = MFMailComposeViewController.canSendMail()
        print("[EMAIL] Can send email: \(canSendEmail)")
    }
    
    // MARK: - Session Email Templates
    
    func composeSessionSummaryEmail(for session: ExecutiveSession, recipients: [String] = []) {
        guard canSendEmail else {
            lastEmailError = "Email is not configured on this device"
            return
        }
        
        isComposingEmail = true
        
        let subject = "Session Summary: \(session.title)"
        let body = generateSessionEmailBody(session)
        
        let emailData = EmailData(
            subject: subject,
            body: body,
            recipients: recipients,
            isHTML: true
        )
        
        presentEmailComposer(with: emailData)
    }
    
    func composeActionItemsEmail(for session: ExecutiveSession, recipients: [String] = []) {
        guard canSendEmail else {
            lastEmailError = "Email is not configured on this device"
            return
        }
        
        let actionItems = session.notes.flatMap { $0.actionItems }
        guard !actionItems.isEmpty else {
            lastEmailError = "No action items found in this session"
            return
        }
        
        isComposingEmail = true
        
        let subject = "Action Items: \(session.title)"
        let body = generateActionItemsEmailBody(session, actionItems: actionItems)
        
        let emailData = EmailData(
            subject: subject,
            body: body,
            recipients: recipients,
            isHTML: true
        )
        
        presentEmailComposer(with: emailData)
    }
    
    // MARK: - Email Template Generation
    
    private func generateSessionEmailBody(_ session: ExecutiveSession) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        var html = """
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #333; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .section { margin: 20px 0; padding: 15px; border-left: 4px solid #667eea; background: #f8f9fa; }
                .action-item { background: #fff3cd; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 3px solid #ffc107; }
                .decision { background: #d1ecf1; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 3px solid #17a2b8; }
                .insight { background: #d4edda; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 3px solid #28a745; }
                .footer { color: #666; font-size: 12px; margin-top: 30px; text-align: center; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>\(session.title)</h1>
                <p><strong>Date:</strong> \(dateFormatter.string(from: session.date))</p>
                <p><strong>Duration:</strong> \(formatDuration(session.duration))</p>
                <p><strong>Type:</strong> \(session.type.rawValue)</p>
                <p><strong>Priority:</strong> \(session.priority.rawValue)</p>
        """
        
        if !session.attendees.isEmpty {
            html += "<p><strong>Attendees:</strong> \(session.attendees.joined(separator: ", "))</p>"
        }
        
        html += "</div>"
        
        // Session Notes
        for note in session.notes {
            html += """
            <div class="section">
                <h2>\(note.title)</h2>
                <p>\(note.content.replacingOccurrences(of: "\n", with: "<br>"))</p>
            """
            
            // Insights
            if !note.insights.isEmpty {
                html += "<h3>Key Insights</h3>"
                for insight in note.insights {
                    html += "<div class=\"insight\">\(insight)</div>"
                }
            }
            
            // Action Items
            if !note.actionItems.isEmpty {
                html += "<h3>Action Items</h3>"
                for actionItem in note.actionItems {
                    html += """
                    <div class="action-item">
                        <strong>\(actionItem.title)</strong><br>
                        \(actionItem.description)
                    """
                    
                    // FIXED: Changed from optional binding to direct access since assignee is non-optional
                    html += "<br><em>Assigned to: \(actionItem.assignee)</em>"
                    
                    if let dueDate = actionItem.dueDate {
                        let dueDateString = dateFormatter.string(from: dueDate)
                        html += "<br><em>Due: \(dueDateString)</em>"
                    }
                    
                    html += "</div>"
                }
            }
            
            // Decisions
            if !note.decisions.isEmpty {
                html += "<h3>Decisions Made</h3>"
                for decision in note.decisions {
                    html += """
                    <div class="decision">
                        <strong>\(decision.title)</strong><br>
                        \(decision.description)<br>
                        <em>Decision maker: \(decision.decisionMaker)</em><br>
                        <em>Rationale: \(decision.rationale)</em>
                    </div>
                    """
                }
            }
            
            html += "</div>"
        }
        
        html += """
            <div class="footer">
                <p>\(EmailConfig.senderSignature)</p>
            </div>
        </body>
        </html>
        """
        
        return html
    }
    
    private func generateActionItemsEmailBody(_ session: ExecutiveSession, actionItems: [ActionItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        var html = """
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #333; }
                .header { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .action-item { background: #fff3cd; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #ffc107; }
                .priority-high { border-left-color: #dc3545; }
                .priority-critical { border-left-color: #721c24; background: #f8d7da; }
                .footer { color: #666; font-size: 12px; margin-top: 30px; text-align: center; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Action Items from \(session.title)</h1>
                <p>\(dateFormatter.string(from: session.date))</p>
                <p>\(actionItems.count) action items require attention</p>
            </div>
        """
        
        for (index, actionItem) in actionItems.enumerated() {
            let priorityClass = actionItem.priority == .critical ? "priority-critical" :
                              actionItem.priority == .high ? "priority-high" : ""
            
            html += """
            <div class="action-item \(priorityClass)">
                <h3>\(index + 1). \(actionItem.title)</h3>
                <p>\(actionItem.description)</p>
                <p><strong>Priority:</strong> \(actionItem.priority.rawValue)</p>
                <p><strong>Status:</strong> \(actionItem.status.rawValue)</p>
            """
            
            // FIXED: Changed from optional binding to direct access since assignee is non-optional
            html += "<p><strong>Assigned to:</strong> \(actionItem.assignee)</p>"
            
            if let dueDate = actionItem.dueDate {
                let dueDateString = dateFormatter.string(from: dueDate)
                html += "<p><strong>Due:</strong> \(dueDateString)</p>"
            }
            
            html += "</div>"
        }
        
        html += """
            <div class="footer">
                <p>\(EmailConfig.senderSignature)</p>
            </div>
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - Email Composer Presentation
    
    private func presentEmailComposer(with emailData: EmailData) {
        guard canSendEmail else {
            lastEmailError = "Email is not available"
            return
        }
        
        // This would typically present MFMailComposeViewController
        // For now, we'll store the email data and let the view handle presentation
        pendingEmailData = emailData
    }
    
    // MARK: - Email Data Storage
    
    private var pendingEmailData: EmailData?
    
    func getPendingEmailData() -> EmailData? {
        return pendingEmailData
    }
    
    func clearPendingEmailData() {
        pendingEmailData = nil
        isComposingEmail = false
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Email Data Model

struct EmailData {
    let subject: String
    let body: String
    let recipients: [String]
    let isHTML: Bool
    
    init(subject: String, body: String, recipients: [String] = [], isHTML: Bool = false) {
        self.subject = subject
        self.body = body
        self.recipients = recipients
        self.isHTML = isHTML
    }
}

//
//  AriaSheetChrome.swift
//  Apprentice
//
//  Shared chrome for Aria-styled sheets: a serif title header with a close
//  button + an ink background that fills the sheet.
//

import SwiftUI

struct AriaSheetHeader<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.fraunces(24, .medium)).foregroundColor(Aria.ivory)
            Spacer()
            trailing()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Aria.ivoryDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Aria.panel))
                    .overlay(Circle().stroke(Aria.lineSoft, lineWidth: 1))
            }
        }
        .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 12)
    }
}

extension AriaSheetHeader where Trailing == EmptyView {
    init(title: String, onClose: @escaping () -> Void) {
        self.init(title: title, onClose: onClose, trailing: { EmptyView() })
    }
}

extension View {
    /// Fill a sheet with the Aria ink background + show the drag indicator.
    func ariaSheetSurface() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AriaBackground())
            .presentationDragIndicator(.visible)
    }

    /// A small round icon button used in sheet headers.
    func ariaHeaderIcon() -> some View {
        self.frame(width: 34, height: 34)
            .background(Circle().fill(Aria.panel))
            .overlay(Circle().stroke(Aria.lineSoft, lineWidth: 1))
    }
}

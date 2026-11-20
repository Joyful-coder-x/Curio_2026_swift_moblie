import SwiftUI
import UIKit

struct ThreadPolaroid: View {
    let store: CurioStore
    let thread: CurioThread
    var width: CGFloat = 166
    var showsMetadata = true
    var archived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(spacing: 0) {
                ThreadCollage(
                    photos: archived ? personalizedPhotos : thread.photos.map(Optional.some),
                    isArchived: archived
                )
                .frame(width: width - 16, height: width - 16)
                .padding(.horizontal, 7)
                .padding(.top, 7)

                Text(thread.prompt)
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(captionColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 5)
            }
            .frame(width: width)
            .background(paperColor)
            .overlay(Rectangle().stroke(Color.curioEdge, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)

            if showsMetadata {
                HStack(spacing: 5) {
                    Text(String(store.name(for: thread.creatorID).prefix(1)))
                        .font(.caption2.weight(.semibold))
                        .frame(width: 19, height: 19)
                        .background(Color.curioAvatar, in: Circle())
                    Text(store.name(for: thread.creatorID))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 2)
                }
                .foregroundStyle(Color.curioInk)

                Text("\(thread.photos.count)/9 · \(statusText)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.curioSecondary)
            }
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(thread.prompt), by \(store.name(for: thread.creatorID)), \(thread.photos.count) of 9 people, \(statusText)")
    }

    private var statusText: String {
        if thread.isExpired { return "Saved" }
        if thread.isFull { return "Full" }
        let minutes = max(1, Int(ceil(thread.expiresAt.timeIntervalSinceNow / 60)))
        return "\(minutes) min left"
    }

    private var deadlineProgress: Double {
        guard !thread.isExpired else { return 0 }
        let remaining = max(0, min(600, thread.expiresAt.timeIntervalSinceNow))
        return 1 - remaining / 600
    }

    private var paperColor: Color {
        archived || thread.isExpired ? .curioPaper : .deadlinePaper(expiresAt: thread.expiresAt)
    }

    private var captionColor: Color {
        deadlineProgress > 0.56 && !archived ? .white : .curioInk
    }

    private var personalizedPhotos: [CurioPhoto?] {
        let centerUserID = thread.photos.contains { $0.userID == store.selectedUserID }
            ? store.selectedUserID
            : thread.creatorID
        let center = thread.photos.first { $0.userID == centerUserID }
        var others = thread.photos.filter { $0.id != center?.id }.map(Optional.some)
        while others.count < 8 { others.append(nil) }
        others.insert(center, at: 4)
        return Array(others.prefix(9))
    }
}

struct ThreadCollage: View {
    let photos: [CurioPhoto?]
    var isArchived = false

    var body: some View {
        GeometryReader { geometry in
            let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: dimension)
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(displaySlots.enumerated()), id: \.offset) { index, photo in
                    CollageCell(
                        photo: photo,
                        placeholderColor: placeholderColor(at: index),
                        isArchived: isArchived
                    )
                    .frame(height: cellLength(for: geometry.size.width))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var actualCount: Int { photos.compactMap { $0 }.count }
    private var dimension: Int {
        if isArchived || actualCount >= 5 { return 3 }
        if actualCount >= 2 { return 2 }
        return 1
    }
    private var slotCount: Int { dimension * dimension }
    private var displaySlots: [CurioPhoto?] {
        if isArchived { return Array((photos + Array(repeating: nil, count: 9)).prefix(9)) }
        var slots = photos
        while slots.count < slotCount { slots.append(nil) }
        return Array(slots.prefix(slotCount))
    }

    private func cellLength(for width: CGFloat) -> CGFloat {
        (width - CGFloat(dimension - 1)) / CGFloat(dimension)
    }

    private func placeholderColor(at index: Int) -> Color {
        let palette = ["gold", "ochre", "rose", "green", "blue", "orange", "plum", "mint", "yellow"]
        let seed = photos.compactMap { $0?.userID.unicodeScalars.first?.value }.reduce(UInt32(index + 1), +)
        return Color.curio(palette[Int(seed) % palette.count])
    }
}

struct CollageCell: View {
    let photo: CurioPhoto?
    let placeholderColor: Color
    let isArchived: Bool

    var body: some View {
        ZStack {
            if let photo {
                Color.curio(photo.colorName)
                if let imageData = photo.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: photo.symbol)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .foregroundStyle(.white.opacity(0.92))
                }
            } else {
                isArchived ? Color.curioPaper : placeholderColor
            }
        }
        .clipped()
    }
}

struct CompactThreadThumbnail: View {
    let thread: CurioThread

    var body: some View {
        VStack(spacing: 0) {
            ThreadCollage(photos: thread.photos.map(Optional.some))
                .frame(width: 49, height: 49)
                .padding(.horizontal, 3)
                .padding(.top, 3)
            paperColor.frame(height: 4)
        }
        .frame(width: 55, height: 55)
        .background(paperColor)
        .overlay(Rectangle().stroke(Color.curioEdge, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var paperColor: Color {
        thread.isExpired ? .curioPaper : .deadlinePaper(expiresAt: thread.expiresAt)
    }
}

struct PhotoTile: View {
    let photo: CurioPhoto
    let name: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.curio(photo.colorName)
                if let imageData = photo.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Image(systemName: photo.symbol)
                        .resizable()
                        .scaledToFit()
                        .padding(geometry.size.width * 0.24)
                        .foregroundStyle(.white)
                }
                if !name.isEmpty {
                    Text(name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name.isEmpty ? "Photo" : "\(name)'s photo")
    }
}

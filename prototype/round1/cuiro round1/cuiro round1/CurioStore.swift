import Foundation
import Observation
import SwiftUI

struct CurioUser: Identifiable, Hashable {
    let id: String
    let name: String
}

struct CurioPhoto: Identifiable, Hashable {
    let id: UUID
    let userID: String
    let symbol: String
    let colorName: String
    let imageData: Data?
    let acceptedAt: Date

    init(
        id: UUID,
        userID: String,
        symbol: String,
        colorName: String,
        imageData: Data? = nil,
        acceptedAt: Date = Date()
    ) {
        self.id = id
        self.userID = userID
        self.symbol = symbol
        self.colorName = colorName
        self.imageData = imageData
        self.acceptedAt = acceptedAt
    }
}

struct CurioMessage: Identifiable, Hashable {
    let id: UUID
    let userID: String
    let body: String
    let sentAt: Date
}

struct CurioThread: Identifiable, Hashable {
    let id: String
    let creatorID: String
    var prompt: String
    var isPrivate: Bool
    var expiresAt: Date
    var photos: [CurioPhoto]
    var messages: [CurioMessage]
    var deliveredTo: Set<String>

    var isExpired: Bool { Date() >= expiresAt }
    var isFull: Bool { photos.count >= 9 }
}

struct InboxActivity: Identifiable, Hashable {
    enum Kind: Hashable {
        case photo(CurioPhoto)
        case message(CurioMessage)
    }

    let id: String
    let threadID: String
    let actorID: String
    let occurredAt: Date
    let kind: Kind
}

enum CurioRoute: Hashable {
    case create
    case join(String)
    case thread(String)
    case journal(String)
}

enum HomeSection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case inbox = "Inbox"
    case mine = "Mine"

    var id: Self { self }
}

@MainActor
@Observable
final class CurioStore {
    static let users = [
        CurioUser(id: "A", name: "Maya"), CurioUser(id: "B", name: "Jun"),
        CurioUser(id: "C", name: "Rae"), CurioUser(id: "D", name: "Leo"),
        CurioUser(id: "E", name: "Ana"), CurioUser(id: "F", name: "Sam"),
        CurioUser(id: "G", name: "Iris"), CurioUser(id: "H", name: "Uma"),
        CurioUser(id: "I", name: "Noa"), CurioUser(id: "J", name: "Kai")
    ]

    var selectedUserID = "B"
    var selectedSection: HomeSection = .discover
    var path: [CurioRoute] = []
    var threads: [CurioThread] = CurioStore.fixtures()
    var notice: String?

    var selectedUser: CurioUser {
        Self.users.first { $0.id == selectedUserID } ?? Self.users[0]
    }

    func name(for userID: String) -> String {
        Self.users.first { $0.id == userID }?.name ?? userID
    }

    func homeThreads() -> [CurioThread] {
        switch selectedSection {
        case .discover:
            return threads.filter { !$0.isExpired && !$0.isFull }
        case .inbox:
            // Inbox is contributor activity, not invitation delivery. People who have
            // only received or viewed a thread continue to find it in Discover.
            return threads.filter { isMember(of: $0) }
        case .mine:
            return threads.filter { isMember(of: $0) }
        }
    }

    func inboxActivities() -> [InboxActivity] {
        var activities: [InboxActivity] = []
        for thread in threads where isMember(of: thread) {
            for photo in thread.photos.dropFirst() where photo.userID != selectedUserID {
                activities.append(
                    InboxActivity(
                        id: "photo-\(thread.id)-\(photo.id)",
                        threadID: thread.id,
                        actorID: photo.userID,
                        occurredAt: photo.acceptedAt,
                        kind: .photo(photo)
                    )
                )
            }
            for message in thread.messages where message.userID != selectedUserID {
                activities.append(
                    InboxActivity(
                        id: "message-\(thread.id)-\(message.id)",
                        threadID: thread.id,
                        actorID: message.userID,
                        occurredAt: message.sentAt,
                        kind: .message(message)
                    )
                )
            }
        }
        return activities.sorted { $0.occurredAt > $1.occurredAt }
    }

    func thread(id: String) -> CurioThread? {
        threads.first { $0.id == id }
    }

    func open(_ thread: CurioThread) {
        path.append(thread.isExpired ? .journal(thread.id) : .thread(thread.id))
    }

    func isMember(of thread: CurioThread) -> Bool {
        thread.photos.contains { $0.userID == selectedUserID }
    }

    func publish(prompt: String, isPrivate: Bool, symbol: String, colorName: String, imageData: Data?) {
        let id = String(UUID().uuidString.prefix(8))
        let recipients = Set(Self.users.map(\.id).filter { $0 != selectedUserID })
        let thread = CurioThread(
            id: id,
            creatorID: selectedUserID,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            isPrivate: isPrivate,
            expiresAt: Date().addingTimeInterval(600),
            photos: [CurioPhoto(id: UUID(), userID: selectedUserID, symbol: symbol, colorName: colorName, imageData: imageData)],
            messages: [],
            deliveredTo: isPrivate ? [] : recipients
        )
        threads.insert(thread, at: 0)
        path = [.thread(id)]
    }

    func join(threadID: String, symbol: String, colorName: String, imageData: Data?) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }),
              !threads[index].isExpired,
              !threads[index].isFull,
              !isMember(of: threads[index]) else {
            notice = "Joining is no longer available. Your photo was not submitted."
            return
        }
        threads[index].photos.append(
            CurioPhoto(id: UUID(), userID: selectedUserID, symbol: symbol, colorName: colorName, imageData: imageData)
        )
        path = [.thread(threadID)]
    }

    func sendMessage(_ body: String, threadID: String) {
        let cleaned = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let index = threads.firstIndex(where: { $0.id == threadID }),
              isMember(of: threads[index]),
              !threads[index].isExpired else { return }
        threads[index].messages.append(
            CurioMessage(id: UUID(), userID: selectedUserID, body: cleaned, sentAt: Date())
        )
    }

    func advanceDemoClock() {
        for index in threads.indices where !threads[index].isExpired {
            threads[index].expiresAt = Date().addingTimeInterval(-1)
        }
        path.removeAll()
        notice = "Demo clock advanced. Open Mine to see saved journals."
    }

    func resetFixtures() {
        threads = Self.fixtures()
        path.removeAll()
        notice = "Round-one sample data restored."
    }

    private static func fixtures() -> [CurioThread] {
        let palette = ["yellow", "orange", "blue", "green", "purple", "pink", "mint", "indigo", "red"]
        let symbols = ["bicycle", "sun.max.fill", "camera.macro", "leaf.fill", "sparkles", "heart.fill", "drop.fill", "moon.stars.fill", "flame.fill"]
        // The saved journal fixture contains nine contributors, but G · Iris is
        // intentionally not one of them so her Inbox demonstrates the empty state.
        let journalUsers = users.filter { $0.id != "G" }
        let completePhotos = zip(journalUsers.prefix(9), zip(symbols, palette)).map { user, visual in
            CurioPhoto(id: UUID(), userID: user.id, symbol: visual.0, colorName: visual.1)
        }
        return [
            CurioThread(
                id: "YELLOW",
                creatorID: "A",
                prompt: "Find something yellow.",
                isPrivate: false,
                expiresAt: Date().addingTimeInterval(600),
                photos: [CurioPhoto(id: UUID(), userID: "A", symbol: "bicycle", colorName: "yellow")],
                messages: [],
                deliveredTo: Set(users.dropFirst().map(\.id))
            ),
            CurioThread(
                id: "SUNLIGHT",
                creatorID: "A",
                prompt: "What caught the sunlight?",
                isPrivate: false,
                expiresAt: Date().addingTimeInterval(-3600),
                photos: completePhotos,
                messages: [CurioMessage(id: UUID(), userID: "B", body: "I found mine on the walk home.", sentAt: Date().addingTimeInterval(-4000))],
                deliveredTo: Set(users.dropFirst().map(\.id))
            )
        ]
    }
}

extension Color {
    static func curio(_ name: String) -> Color {
        switch name {
        case "yellow": .yellow
        case "orange": .orange
        case "blue": .blue
        case "green": .green
        case "purple": .purple
        case "pink": .pink
        case "mint": .mint
        case "indigo": .indigo
        case "red": .red
        default: .gray
        }
    }
}

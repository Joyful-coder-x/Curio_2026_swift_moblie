import Foundation
import Observation
import SwiftUI

struct CurioUser: Identifiable, Hashable {
    let id: String
    let name: String
    let testRole: String
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
    var latestActivityAt: Date {
        max(photos.map(\.acceptedAt).max() ?? .distantPast, messages.map(\.sentAt).max() ?? .distantPast)
    }
}

enum CurioTimelineEntry: Identifiable {
    case photo(CurioPhoto)
    case message(CurioMessage)

    var id: String {
        switch self {
        case .photo(let photo): "photo-\(photo.id)"
        case .message(let message): "message-\(message.id)"
        }
    }

    var date: Date {
        switch self {
        case .photo(let photo): photo.acceptedAt
        case .message(let message): message.sentAt
        }
    }
}

enum CurioRoute: Hashable {
    case create
    case join(String)
    case thread(String)
    case journal(String)
}

enum HomeSection: String, CaseIterable, Identifiable {
    case discover = "Home"
    case inbox = "Inbox"
    case mine = "Mine"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .discover: "house"
        case .inbox: "tray"
        case .mine: "person"
        }
    }
}

enum MineFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case created = "Created"
    case joined = "Joined"

    var id: Self { self }
}

enum DiscoverFilter: String, CaseIterable, Identifiable {
    case random = "Random"
    case following = "Following"

    var id: Self { self }
}

@MainActor
@Observable
final class CurioStore {
    static let users = [
        CurioUser(id: "A", name: "Maya", testRole: "Create"),
        CurioUser(id: "B", name: "Jun", testRole: "Saved journal"),
        CurioUser(id: "C", name: "Rea", testRole: "Join invitation"),
        CurioUser(id: "D", name: "Leo", testRole: "Member chat"),
        CurioUser(id: "E", name: "Eli", testRole: "Near deadline"),
        CurioUser(id: "F", name: "Sam", testRole: "Full thread"),
        CurioUser(id: "G", name: "Iris", testRole: "Empty inbox / visitor"),
        CurioUser(id: "H", name: "Uma", testRole: "Private follower"),
        CurioUser(id: "I", name: "Nora", testRole: "Ninth-slot race"),
        CurioUser(id: "J", name: "Kaia", testRole: "Invite-link access")
    ]

    var selectedUserID = "B"
    var selectedSection: HomeSection = .discover
    var discoverFilter: DiscoverFilter = .random
    var mineFilter: MineFilter = .all
    var path: [CurioRoute] = []
    var threads: [CurioThread] = CurioStore.fixtures()
    var notice: String?

    private let followingByUser: [String: Set<String>] = [
        "A": ["D", "I"],
        "B": ["A"],
        "C": ["A", "F"],
        "D": ["C"],
        "E": ["B", "J"],
        "F": ["E"],
        "G": ["A", "H"],
        "H": ["G"],
        "I": ["A", "D"],
        "J": ["E"]
    ]

    var selectedUser: CurioUser {
        Self.users.first { $0.id == selectedUserID } ?? Self.users[0]
    }

    func name(for userID: String) -> String {
        Self.users.first { $0.id == userID }?.name ?? userID
    }

    func discoverThreads() -> [CurioThread] {
        threads.filter { thread in
            guard !thread.isExpired, !thread.isFull else { return false }
            return discoverFilter == .random || followingUserIDs.contains(thread.creatorID)
        }
        .sorted { $0.latestActivityAt > $1.latestActivityAt }
    }

    var followingUserIDs: Set<String> {
        followingByUser[selectedUserID] ?? []
    }

    var followedUsers: [CurioUser] {
        Self.users.filter { followingUserIDs.contains($0.id) }
    }

    func inboxThreads() -> [CurioThread] {
        threads.filter { isMember(of: $0) && $0.latestActivityAt > contributionDate(in: $0) }
            .sorted { $0.latestActivityAt > $1.latestActivityAt }
    }

    func mineThreads(saved: Bool) -> [CurioThread] {
        threads.filter { thread in
            guard isMember(of: thread), thread.isExpired == saved else { return false }
            switch mineFilter {
            case .all: return true
            case .created: return thread.creatorID == selectedUserID
            case .joined: return thread.creatorID != selectedUserID
            }
        }
        .sorted { saved ? $0.expiresAt > $1.expiresAt : $0.expiresAt < $1.expiresAt }
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

    func timeline(for thread: CurioThread) -> [CurioTimelineEntry] {
        (thread.photos.map(CurioTimelineEntry.photo) + thread.messages.map(CurioTimelineEntry.message))
            .sorted { $0.date < $1.date }
    }

    func latestActivityText(for thread: CurioThread) -> String {
        guard let latest = timeline(for: thread).last else { return "Invitation created" }
        switch latest {
        case .photo(let photo): return "\(name(for: photo.userID)) joined with a photo"
        case .message(let message): return "\(name(for: message.userID)): \(message.body)"
        }
    }

    func switchAccount(to userID: String) {
        selectedUserID = userID
        path.removeAll()
        notice = "Signed in locally as \(selectedUser.name)."
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
        selectedSection = .mine
        notice = "Demo clock advanced. Active threads are now saved journals."
    }

    func resetFixtures() {
        threads = Self.fixtures()
        path.removeAll()
        selectedSection = .discover
        notice = "Round-one sample data restored."
    }

    private func contributionDate(in thread: CurioThread) -> Date {
        thread.photos.first { $0.userID == selectedUserID }?.acceptedAt ?? .distantFuture
    }

    private static func fixtures() -> [CurioThread] {
        let prompts = [
            "Find something yellow.", "What’s blooming on your block?", "Show me a rainy-day color.",
            "Where did the sunlight land?", "What’s in your fruit bowl?", "A window worth stopping for?",
            "Match my morning sky.", "Find a tiny pattern.", "What made you look twice?",
            "Show me something soft.", "A color from your commute.", "What feels like spring?",
            "Find an accidental still life.", "What’s on your desk today?", "Show me a quiet corner.",
            "A shape hiding in plain sight.", "Find this shade of green.", "What are you carrying?",
            "Show me a favorite shadow.", "What’s moving around you?", "Find something handmade.",
            "A detail from dinner.", "What caught the evening light?", "Show me today’s texture.",
            "Where did you pause?"
        ]
        let symbols = ["bicycle", "camera.macro", "umbrella.fill", "sunflower.fill", "carrot.fill", "window.vertical.open", "cloud.sun.fill", "circle.hexagongrid.fill", "eye.fill"]
        let colors = ["rose", "gold", "blue", "ochre", "green", "plum", "mint", "orange", "pink"]
        let base = Date().addingTimeInterval(-120)
        var result = prompts.enumerated().map { index, prompt in
            let count = [1, 1, 3, 5, 4, 5, 2, 7, 1][index % 9]
            let creatorIndex = index % users.count
            let contributorIDs = (0..<count).map { users[($0 + creatorIndex) % users.count].id }
            let photos = contributorIDs.enumerated().map { offset, userID in
                CurioPhoto(
                    id: UUID(),
                    userID: userID,
                    symbol: symbols[(index + offset) % symbols.count],
                    colorName: colors[(index + offset) % colors.count],
                    acceptedAt: base.addingTimeInterval(Double(index * 4 + offset))
                )
            }
            return CurioThread(
                id: index == 0 ? "YELLOW" : "DISCOVER-\(index + 1)",
                creatorID: users[creatorIndex].id,
                prompt: prompt,
                isPrivate: false,
                expiresAt: Date().addingTimeInterval(Double(600 - index * 8)),
                photos: photos,
                messages: index == 1 ? [CurioMessage(id: UUID(), userID: contributorIDs[0], body: "I found this on my walk.", sentAt: base.addingTimeInterval(200))] : [],
                deliveredTo: Set(users.map(\.id).filter { $0 != users[creatorIndex].id })
            )
        }

        let archivedUsers = users.filter { $0.id != "G" }
        let archivedPhotos = archivedUsers.prefix(9).enumerated().map { offset, user in
            CurioPhoto(
                id: UUID(), userID: user.id,
                symbol: symbols[offset % symbols.count], colorName: colors[offset % colors.count],
                acceptedAt: base.addingTimeInterval(Double(offset * 20))
            )
        }
        result.append(
            CurioThread(
                id: "SUNLIGHT", creatorID: "A", prompt: "What caught the sunlight?", isPrivate: false,
                expiresAt: Date().addingTimeInterval(-3600), photos: archivedPhotos,
                messages: [
                    CurioMessage(id: UUID(), userID: "B", body: "I found mine on the walk home.", sentAt: base.addingTimeInterval(220)),
                    CurioMessage(id: UUID(), userID: "A", body: "The colors look so good together.", sentAt: base.addingTimeInterval(240))
                ],
                deliveredTo: Set(users.dropFirst().map(\.id))
            )
        )
        return result
    }
}

extension Color {
    static let curioCanvas = Color(hex: 0xF3F0E9)
    static let curioPaper = Color(hex: 0xFFFCF5)
    static let curioInk = Color(hex: 0x49392F)
    static let curioPlum = Color(hex: 0x59434D)
    static let curioAction = Color(hex: 0x502653)
    static let curioSelected = Color(hex: 0x982E50)
    static let curioSecondary = Color(hex: 0x635866)
    static let curioEdge = Color(hex: 0xDFD9CE)
    static let curioReceived = Color(hex: 0xEDE7E0)
    static let curioSent = Color(hex: 0xEADCE4)
    static let curioEmpty = Color(hex: 0xE9E4DC)
    static let curioAvatar = Color(hex: 0xE3D3CB)

    static func deadlinePaper(expiresAt: Date) -> Color {
        let remaining = max(0, min(600, expiresAt.timeIntervalSinceNow))
        let progress = 1 - remaining / 600
        return Color(
            .sRGB,
            red: interpolate(from: 0xFF, to: 0x50, progress: progress),
            green: interpolate(from: 0xFC, to: 0x26, progress: progress),
            blue: interpolate(from: 0xF5, to: 0x53, progress: progress),
            opacity: 1
        )
    }

    private static func interpolate(from: UInt, to: UInt, progress: Double) -> Double {
        let start = Double(from) / 255
        let end = Double(to) / 255
        return start + (end - start) * progress
    }

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }

    static func curio(_ name: String) -> Color {
        switch name {
        case "yellow": Color(hex: 0xE7C34F)
        case "gold": Color(hex: 0xC7A34E)
        case "orange": Color(hex: 0xD58A4B)
        case "blue": Color(hex: 0x6F91A7)
        case "green": Color(hex: 0x718C69)
        case "purple", "plum": .curioPlum
        case "pink", "rose": Color(hex: 0xC97C87)
        case "mint": Color(hex: 0x8AA99A)
        case "indigo": Color(hex: 0x6E668D)
        case "red": Color(hex: 0xA84F4F)
        case "ochre": Color(hex: 0xAA814F)
        default: Color(hex: 0xA68B6A)
        }
    }
}

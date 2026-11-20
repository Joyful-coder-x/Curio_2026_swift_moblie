import SwiftUI

struct JournalView: View {
    let store: CurioStore
    let threadID: String
    @State private var showsConversation = false

    var body: some View {
        if let thread = store.thread(id: threadID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Saved journal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(thread.prompt)
                        .font(.largeTitle.bold())
                    JournalCover(store: store, thread: thread)
                    ContributorList(store: store, photos: thread.photos)
                    if store.isMember(of: thread) {
                        DisclosureGroup("Conversation history", isExpanded: $showsConversation) {
                            ConversationView(store: store, messages: thread.messages)
                                .padding(.top)
                        }
                    } else {
                        Label("Joiners can read the conversation history.", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                    ShareLink(item: "curio://thread/\(thread.id)") {
                        Label("Share invitation", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Journal unavailable", systemImage: "book.closed")
        }
    }
}

struct JournalCover: View {
    let store: CurioStore
    let thread: CurioThread

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Array(arrangedPhotos.enumerated()), id: \.offset) { _, photo in
                if let photo {
                    PhotoTile(photo: photo, name: store.name(for: photo.userID))
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                }
            }
        }
        .padding(8)
        .background(.black, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nine-photo journal cover")
    }

    private var arrangedPhotos: [CurioPhoto?] {
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

struct ContributorList: View {
    let store: CurioStore
    let photos: [CurioPhoto]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contributors")
                .font(.title2.bold())
            ForEach(photos) { photo in
                Label(store.name(for: photo.userID), systemImage: "person.crop.circle.fill")
            }
        }
    }
}

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var store = CurioStore()

    var body: some View {
        NavigationStack(path: $store.path) {
            HomeView(store: store)
                .navigationDestination(for: CurioRoute.self) { route in
                    switch route {
                    case .create:
                        PhotoFormView(store: store, mode: .create)
                    case .join(let threadID):
                        PhotoFormView(store: store, mode: .join(threadID))
                    case .thread(let threadID):
                        ThreadView(store: store, threadID: threadID)
                    case .journal(let threadID):
                        JournalView(store: store, threadID: threadID)
                    }
                }
        }
        .tint(.black)
    }
}

struct HomeView: View {
    let store: CurioStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                DemoAccountBar(store: store)
                HomeHeader(store: store)
                HomeSectionPicker(store: store)
                if let notice = store.notice {
                    NoticeBanner(text: notice)
                }
                if store.selectedSection == .inbox {
                    InboxActivityList(store: store)
                } else {
                    HomeThreadList(store: store)
                }
                DemoControls(store: store)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Curio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeThreadList: View {
    let store: CurioStore

    var body: some View {
        let threads = store.homeThreads()
        ForEach(threads) { thread in
            ThreadCard(store: store, thread: thread)
        }
        if threads.isEmpty {
            ContentUnavailableView(
                "Nothing here yet",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Create an invitation or switch test accounts.")
            )
        }
    }
}

struct InboxActivityList: View {
    let store: CurioStore

    var body: some View {
        let activities = store.inboxActivities()
        ForEach(activities) { activity in
            InboxActivityRow(store: store, activity: activity)
        }
        if activities.isEmpty {
            ContentUnavailableView(
                "No activity yet",
                systemImage: "tray",
                description: Text("Photo replies and messages from your threads will appear here.")
            )
        }
    }
}

struct InboxActivityRow: View {
    let store: CurioStore
    let activity: InboxActivity

    var body: some View {
        Button {
            if let thread = store.thread(id: activity.threadID) {
                store.open(thread)
            }
        } label: {
            HStack(spacing: 14) {
                InboxActivityThumbnail(
                    activity: activity,
                    photos: store.thread(id: activity.threadID)?.photos ?? []
                )
                VStack(alignment: .leading, spacing: 5) {
                    InboxActivityText(
                        activity: activity,
                        actorName: store.name(for: activity.actorID)
                    )
                    if let thread = store.thread(id: activity.threadID) {
                        Text(thread.prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(activity.occurredAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

struct InboxActivityThumbnail: View {
    let activity: InboxActivity
    let photos: [CurioPhoto]

    var body: some View {
        switch activity.kind {
        case .photo(let photo):
            PhotoTile(photo: photo, name: "")
                .frame(width: 64, height: 64)
        case .message:
            InboxPhotoGrid(photos: photos)
                .frame(width: 64, height: 64)
        }
    }
}

struct InboxGridSlot: Identifiable {
    let id: Int
    let photo: CurioPhoto?
}

struct InboxPhotoGrid: View {
    let photos: [CurioPhoto]

    var body: some View {
        let slots = (0..<9).map { index in
            InboxGridSlot(id: index, photo: photos.indices.contains(index) ? photos[index] : nil)
        }
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
            spacing: 1
        ) {
            ForEach(slots) { slot in
                InboxPhotoGridCell(photo: slot.photo)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(2)
        .background(.black, in: RoundedRectangle(cornerRadius: 9))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thread photos, \(photos.count) of 9 filled")
    }
}

struct InboxPhotoGridCell: View {
    let photo: CurioPhoto?

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
                        .padding(3)
                        .foregroundStyle(.white)
                }
            } else {
                Color(.secondarySystemBackground)
            }
        }
        .clipped()
    }
}

struct InboxActivityText: View {
    let activity: InboxActivity
    let actorName: String

    var body: some View {
        switch activity.kind {
        case .photo:
            Text("\(actorName) responded with a photo")
                .font(.headline)
                .foregroundStyle(.primary)
        case .message(let message):
            Text("\(actorName) said “\(message.body)”")
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}

struct DemoAccountBar: View {
    let store: CurioStore

    var body: some View {
        HStack {
            Label("Simulator account", systemImage: "person.crop.circle.badge.checkmark")
                .font(.caption.weight(.semibold))
            Spacer()
            Picker("Simulator account", selection: Bindable(store).selectedUserID) {
                ForEach(CurioStore.users) { user in
                    Text("\(user.id) · \(user.name)").tag(user.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: store.selectedUserID) {
            store.path.removeAll()
            store.notice = "Signed in locally as \(store.selectedUser.name)."
        }
    }
}

struct HomeHeader: View {
    let store: CurioStore

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Photo invitations")
                    .font(.largeTitle.bold())
                Text("Share one moment. Build one journal.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.path.append(.create)
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct HomeSectionPicker: View {
    let store: CurioStore

    var body: some View {
        Picker("Library", selection: Bindable(store).selectedSection) {
            ForEach(HomeSection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ThreadCard: View {
    let store: CurioStore
    let thread: CurioThread

    var body: some View {
        Button {
            store.open(thread)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                PhotoTile(photo: thread.photos[0], name: store.name(for: thread.creatorID))
                    .frame(height: 180)
                Text("\(store.name(for: thread.creatorID)) · \(thread.isPrivate ? "Private" : "Public")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(thread.prompt)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                HStack {
                    Label(thread.isExpired ? "Saved" : thread.isFull ? "Full" : "Open", systemImage: thread.isExpired ? "book.closed.fill" : "clock")
                    Spacer()
                    Text("\(thread.photos.count)/9")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

struct DemoControls: View {
    let store: CurioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Round-one test controls")
                .font(.headline)
            Text("These controls are simulator-only. Firebase Emulator accounts replace this switcher in the connected build.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Advance 10 min") { store.advanceDemoClock() }
                    .buttonStyle(.bordered)
                Button("Reset samples") { store.resetFixtures() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct NoticeBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct PhotoTile: View {
    let photo: CurioPhoto
    let name: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color.curio(photo.colorName), Color.curio(photo.colorName).opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let imageData = photo.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: photo.symbol)
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(.white)
                }
                if !name.isEmpty {
                    Text(name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name.isEmpty ? "Photo" : "\(name)'s photo")
    }
}

#Preview {
    ContentView()
}

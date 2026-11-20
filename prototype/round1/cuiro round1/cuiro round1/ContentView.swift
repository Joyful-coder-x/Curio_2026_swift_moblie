import SwiftUI

struct ContentView: View {
    @State private var store = CurioStore()

    var body: some View {
        NavigationStack(path: $store.path) {
            HomeView(store: store)
                .navigationDestination(for: CurioRoute.self) { route in
                    switch route {
                    case .create: PhotoFormView(store: store, mode: .create)
                    case .join(let threadID): PhotoFormView(store: store, mode: .join(threadID))
                    case .thread(let threadID): ThreadView(store: store, threadID: threadID)
                    case .journal(let threadID): JournalView(store: store, threadID: threadID)
                    }
                }
        }
        .tint(Color.curioAction)
    }
}

struct HomeView: View {
    let store: CurioStore

    var body: some View {
        Group {
            switch store.selectedSection {
            case .discover: DiscoverView(store: store)
            case .inbox: InboxView(store: store)
            case .mine: MineView(store: store)
            }
        }
        .background(Color.curioCanvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SettingsAccountMenu(store: store)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CurioBottomNavigation(store: store)
        }
    }

    private var title: String {
        switch store.selectedSection {
        case .discover: "Discover"
        case .inbox: "Inbox"
        case .mine: "Mine"
        }
    }
}

struct DiscoverView: View {
    let store: CurioStore
    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Discover source", selection: Bindable(store).discoverFilter) {
                    ForEach(DiscoverFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                let threads = store.discoverThreads()
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(threads) { thread in
                        Button { store.open(thread) } label: {
                            ThreadPolaroid(store: store, thread: thread)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if threads.isEmpty {
                    ContentUnavailableView(
                        "No open invitations",
                        systemImage: "person.2.slash",
                        description: Text("People you follow have no open threads right now.")
                    )
                    .padding(.vertical, 50)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { store.path.append(.create) } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.white)
                    .background(Color.curioAction, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
            }
            .accessibilityLabel("New invitation")
            .padding(.trailing, 22)
            .padding(.bottom, 18)
        }
    }
}

struct InboxView: View {
    let store: CurioStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let threads = store.inboxThreads()
                ForEach(threads) { thread in
                    InboxThreadRow(store: store, thread: thread)
                }
                if threads.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "tray",
                        description: Text("Threads appear here after you contribute and someone adds a photo or message.")
                    )
                    .padding(.top, 80)
                }
            }
            .padding(.horizontal, 22)
        }
    }
}

struct InboxThreadRow: View {
    let store: CurioStore
    let thread: CurioThread

    var body: some View {
        Button { store.open(thread) } label: {
            HStack(spacing: 12) {
                CompactThreadThumbnail(thread: thread)
                VStack(alignment: .leading, spacing: 3) {
                    Text(thread.prompt)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.curioInk)
                        .lineLimit(1)
                    Text(store.latestActivityText(for: thread))
                        .font(.caption)
                        .foregroundStyle(Color.curioSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Text(thread.latestActivityAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color.curioSecondary)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { Divider().foregroundStyle(Color.curioEdge) }
        }
        .buttonStyle(.plain)
    }
}

struct MineView: View {
    let store: CurioStore
    @State private var showsFollowing = false
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MineProfileHeader(store: store)
                Button {
                    showsFollowing = true
                } label: {
                    HStack {
                        Label("Following", systemImage: "person.2")
                        Spacer()
                        Text("\(store.followedUsers.count)")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.curioInk)
                    .padding(14)
                    .background(Color.curioPaper, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                Picker("Thread role", selection: Bindable(store).mineFilter) {
                    ForEach(MineFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                MineSection(title: "Active", threads: store.mineThreads(saved: false), store: store, archived: false, columns: columns)
                MineSection(title: "Saved journals", threads: store.mineThreads(saved: true), store: store, archived: true, columns: columns)
                DemoControls(store: store)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showsFollowing) {
            FollowingListView(store: store)
        }
    }
}

struct FollowingListView: View {
    let store: CurioStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(store.followedUsers) { user in
                HStack(spacing: 12) {
                    Text(String(user.name.prefix(1)))
                        .font(.headline)
                        .frame(width: 38, height: 38)
                        .foregroundStyle(Color.curioPlum)
                        .background(Color.curioAvatar, in: Circle())
                    VStack(alignment: .leading) {
                        Text(user.name).font(.headline)
                        Text("\(user.id) · Test \(user.testRole.lowercased())")
                            .font(.caption)
                            .foregroundStyle(Color.curioSecondary)
                    }
                }
            }
            .navigationTitle("Following")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct MineProfileHeader: View {
    let store: CurioStore

    var body: some View {
        HStack(spacing: 14) {
            Text(String(store.selectedUser.name.prefix(1)))
                .font(.title2.bold())
                .frame(width: 52, height: 52)
                .foregroundStyle(Color.curioPlum)
                .background(Color.curioAvatar, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(store.selectedUser.name).font(.title2.bold())
                Text("\(store.selectedUser.id) · Test \(store.selectedUser.testRole.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.curioPlum, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MineSection: View {
    let title: String
    let threads: [CurioThread]
    let store: CurioStore
    let archived: Bool
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).foregroundStyle(Color.curioInk)
            if threads.isEmpty {
                Text("Nothing here yet.").font(.subheadline).foregroundStyle(Color.curioSecondary)
            } else {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(threads) { thread in
                        Button { store.open(thread) } label: {
                            ThreadPolaroid(store: store, thread: thread, archived: archived)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SettingsAccountMenu: View {
    let store: CurioStore

    var body: some View {
        Menu {
            Section("Signed in as \(store.selectedUser.name)") {
                ForEach(CurioStore.users) { user in
                    Button {
                        store.switchAccount(to: user.id)
                    } label: {
                        if user.id == store.selectedUserID {
                            Label("\(user.id) · \(user.name) — \(user.testRole)", systemImage: "checkmark")
                        } else {
                            Text("\(user.id) · \(user.name) — \(user.testRole)")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Settings and account")
    }
}

struct CurioBottomNavigation: View {
    let store: CurioStore

    var body: some View {
        HStack {
            ForEach(HomeSection.allCases) { section in
                Button {
                    store.selectedSection = section
                    store.path.removeAll()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: store.selectedSection == section ? "\(section.symbol).fill" : section.symbol)
                        Text(section.rawValue).font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(store.selectedSection == section ? Color.curioSelected : Color.curioSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background(Color.curioPaper.shadow(.drop(color: .black.opacity(0.08), radius: 2, y: -1)))
    }
}

struct DemoControls: View {
    let store: CurioStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Round-one test controls").font(.headline)
            HStack {
                Button("Advance 10 min") { store.advanceDemoClock() }
                Button("Reset samples") { store.resetFixtures() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.curioPaper, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview { ContentView() }

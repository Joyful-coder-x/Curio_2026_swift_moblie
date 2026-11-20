import SwiftUI
import PhotosUI
import UIKit

enum PhotoFormMode: Hashable {
    case create
    case join(String)
}

struct PhotoFormView: View {
    let store: CurioStore
    let mode: PhotoFormMode
    @State private var prompt = ""
    @State private var isPrivate = false
    @State private var selectedSymbol = "camera.macro"
    @State private var selectedColor = "orange"
    @State private var imageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showsCamera = false
    @State private var isConfirmed = false

    private let choices = [
        ("bicycle", "yellow"), ("camera.macro", "orange"),
        ("leaf.fill", "green"), ("moon.stars.fill", "indigo")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(isConfirmed ? "Ready to send?" : "Choose your photo")
                    .font(.largeTitle.bold())
                PhotoTile(
                    photo: CurioPhoto(
                        id: UUID(),
                        userID: store.selectedUserID,
                        symbol: selectedSymbol,
                        colorName: selectedColor,
                        imageData: imageData
                    ),
                    name: store.selectedUser.name
                )
                .frame(height: 310)
                if let photoError {
                    Label(photoError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                if isConfirmed {
                    ConfirmedPhotoForm(
                        store: store,
                        mode: mode,
                        prompt: $prompt,
                        isPrivate: $isPrivate,
                        onRetake: { isConfirmed = false },
                        onSubmit: submit
                    )
                } else {
                    PhotoSourceButtons(
                        photoItem: $photoItem,
                        showsCamera: $showsCamera,
                        isLoading: isLoadingPhoto
                    )
                    Text("Or choose a simulator sample")
                        .font(.headline)
                    HStack {
                        ForEach(choices, id: \.0) { symbol, color in
                            Button {
                                imageData = nil
                                selectedSymbol = symbol
                                selectedColor = color
                                photoError = nil
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.curio(color).opacity(selectedSymbol == symbol && imageData == nil ? 0.8 : 0.18), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Choose \(color) sample")
                        }
                    }
                    Button("Use this photo") { isConfirmed = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoadingPhoto)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle(modeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCamera) {
            CameraPicker { data in
                imageData = data
                selectedColor = "gray"
                photoError = nil
            }
        }
        .onChange(of: photoItem) {
            loadSelectedPhoto()
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: "New invitation"
        case .join: "Add a photo"
        }
    }

    private func loadSelectedPhoto() {
        guard let photoItem else { return }
        isLoadingPhoto = true
        photoError = nil
        Task {
            do {
                guard let loadedData = try await photoItem.loadTransferable(type: Data.self),
                      UIImage(data: loadedData) != nil else {
                    throw PhotoSelectionError.invalidImage
                }
                imageData = loadedData
                selectedColor = "gray"
            } catch {
                photoError = "The photo could not be loaded. Try another image."
            }
            isLoadingPhoto = false
        }
    }

    private func submit() {
        switch mode {
        case .create:
            store.publish(
                prompt: prompt,
                isPrivate: isPrivate,
                symbol: selectedSymbol,
                colorName: selectedColor,
                imageData: imageData
            )
        case .join(let threadID):
            store.join(
                threadID: threadID,
                symbol: selectedSymbol,
                colorName: selectedColor,
                imageData: imageData
            )
        }
    }
}

struct ConfirmedPhotoForm: View {
    let store: CurioStore
    let mode: PhotoFormMode
    @Binding var prompt: String
    @Binding var isPrivate: Bool
    let onRetake: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        Button("Retake", action: onRetake)
            .buttonStyle(.bordered)
        switch mode {
        case .create:
            TextField("Find something yellow.", text: $prompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Picker("Audience", selection: $isPrivate) {
                Text("Public").tag(false)
                Text("Private").tag(true)
            }
            .pickerStyle(.segmented)
            Text(isPrivate ? "Followers receive it. A signed-in link holder can view." : "Delivered to every other test account.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .join(let threadID):
            if let thread = store.thread(id: threadID) {
                Text(thread.prompt)
                    .font(.title2.bold())
            }
        }
        Label("Once accepted, your photo is permanent.", systemImage: "lock.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
        Button(submitTitle, action: onSubmit)
            .buttonStyle(.borderedProminent)
            .disabled(mode == .create && prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .frame(maxWidth: .infinity)
    }

    private var submitTitle: String {
        switch mode {
        case .create: "Publish invitation"
        case .join: "Send photo & join"
        }
    }
}

struct ThreadView: View {
    let store: CurioStore
    let threadID: String
    @State private var message = ""

    var body: some View {
        if let thread = store.thread(id: threadID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ThreadSummary(store: store, thread: thread)
                    PhotoStrip(store: store, photos: thread.photos)
                    if store.isMember(of: thread) {
                        ConversationView(store: store, messages: thread.messages)
                        MessageComposer(message: $message) {
                            store.sendMessage(message, threadID: threadID)
                            message = ""
                        }
                    } else if !thread.isFull {
                        Button {
                            store.path.append(.join(threadID))
                        } label: {
                            Label("Add a photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Live thread")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Thread unavailable", systemImage: "exclamationmark.triangle")
        }
    }
}

struct ThreadSummary: View {
    let store: CurioStore
    let thread: CurioThread

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(store.name(for: thread.creatorID)) · \(thread.isPrivate ? "Private" : "Public")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(thread.prompt)
                .font(.largeTitle.bold())
            HStack {
                Label("\(thread.photos.count)/9 people", systemImage: "person.2.fill")
                Spacer()
                Label(thread.isExpired ? "Saved" : "10 min round", systemImage: "clock.fill")
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

struct PhotoStrip: View {
    let store: CurioStore
    let photos: [CurioPhoto]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                ForEach(photos) { photo in
                    PhotoTile(photo: photo, name: store.name(for: photo.userID))
                        .frame(width: 150, height: 180)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct ConversationView: View {
    let store: CurioStore
    let messages: [CurioMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation")
                .font(.title2.bold())
            if messages.isEmpty {
                Text("No messages yet. Say what you noticed.")
                    .foregroundStyle(.secondary)
            }
            ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.name(for: message.userID))
                        .font(.caption.bold())
                    Text(message.body)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct MessageComposer: View {
    @Binding var message: String
    let onSend: () -> Void

    var body: some View {
        HStack {
            TextField("Write a message", text: $message)
                .textFieldStyle(.roundedBorder)
            Button("Send", action: onSend)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

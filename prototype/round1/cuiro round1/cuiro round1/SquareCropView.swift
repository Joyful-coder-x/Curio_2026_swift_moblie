import SwiftUI
import UIKit

struct SquareCropView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUse: (Data) -> Void

    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @GestureState private var gestureScale = 1.0
    @GestureState private var gestureOffset = CGSize.zero
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                GeometryReader { geometry in
                    let availableWidth = max(1, geometry.size.width - 32)
                    let availableHeight = max(1, geometry.size.height - 180)
                    let side = max(1, min(availableWidth, availableHeight))
                    VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    CropCanvas(
                        image: image,
                        side: side,
                        scale: scale * gestureScale,
                        offset: constrainedOffset(
                            adding: offset,
                            and: gestureOffset,
                            scale: scale * gestureScale,
                            side: side
                        )
                    )
                    .frame(width: side, height: side)
                    .contentShape(Rectangle())
                    .gesture(cropGesture(side: side))
                    Text("Pinch to zoom and drag to position your square.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                    .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use square crop") {
                            useCrop(side: side)
                        }
                        .fontWeight(.semibold)
                    }
                    }
                }
            }
            .navigationTitle("Crop photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationBackground(Color(.systemBackground))
        .interactiveDismissDisabled()
    }

    private func cropGesture(side: CGFloat) -> some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .updating($gestureScale) { value, state, _ in
                    state = value.magnification
                }
                .onEnded { value in
                    scale = min(max(scale * value.magnification, 1), 6)
                    offset = constrainedOffset(
                        adding: offset,
                        and: .zero,
                        scale: scale,
                        side: side
                    )
                },
            DragGesture()
                .updating($gestureOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    offset = constrainedOffset(
                        adding: offset,
                        and: value.translation,
                        scale: scale,
                        side: side
                    )
                }
        )
    }

    private func constrainedOffset(
        adding base: CGSize,
        and translation: CGSize,
        scale: CGFloat,
        side: CGFloat
    ) -> CGSize {
        let normalized = image.normalizedForCropping()
        let baseScale = max(side / normalized.size.width, side / normalized.size.height)
        let displayedWidth = normalized.size.width * baseScale * scale
        let displayedHeight = normalized.size.height * baseScale * scale
        let limitX = max(0, (displayedWidth - side) / 2)
        let limitY = max(0, (displayedHeight - side) / 2)
        return CGSize(
            width: min(max(base.width + translation.width, -limitX), limitX),
            height: min(max(base.height + translation.height, -limitY), limitY)
        )
    }

    private func useCrop(side: CGFloat) {
        let finalOffset = constrainedOffset(
            adding: offset,
            and: .zero,
            scale: scale,
            side: side
        )
        guard let data = image.squareJPEG(
            viewportSide: side,
            zoom: scale,
            offset: finalOffset
        ) else {
            errorMessage = "The square crop could not be created. Try repositioning the photo."
            return
        }
        onUse(data)
    }
}

struct CropCanvas: View {
    let image: UIImage
    let side: CGFloat
    let scale: CGFloat
    let offset: CGSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: side, height: side)
            .clipped()
            .overlay {
                Rectangle()
                    .stroke(.white, lineWidth: 2)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
            .background(.black)
            .accessibilityLabel("Square photo crop")
            .accessibilityHint("Pinch to zoom and drag to reposition")
    }
}

private extension UIImage {
    func normalizedForCropping() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func squareJPEG(viewportSide: CGFloat, zoom: CGFloat, offset: CGSize) -> Data? {
        let source = normalizedForCropping()
        guard let cgImage = source.cgImage else { return nil }
        let baseScale = max(viewportSide / source.size.width, viewportSide / source.size.height)
        let pointScale = baseScale * zoom
        let displayedSize = CGSize(
            width: source.size.width * pointScale,
            height: source.size.height * pointScale
        )
        let origin = CGPoint(
            x: ((displayedSize.width - viewportSide) / 2 - offset.width) / pointScale,
            y: ((displayedSize.height - viewportSide) / 2 - offset.height) / pointScale
        )
        let cropSide = viewportSide / pointScale
        let imageScaleX = CGFloat(cgImage.width) / source.size.width
        let imageScaleY = CGFloat(cgImage.height) / source.size.height
        let pixelRect = CGRect(
            x: origin.x * imageScaleX,
            y: origin.y * imageScaleY,
            width: cropSide * imageScaleX,
            height: cropSide * imageScaleY
        ).integral
        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        let croppedImage = UIImage(cgImage: cropped)
        let outputSize = CGSize(width: 1200, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let output = UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }
        return output.jpegData(compressionQuality: 0.82)
    }
}

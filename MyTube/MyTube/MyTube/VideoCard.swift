import SwiftUI

struct VideoCard: View {
    let video: ResolvedVideo
    var onHoverChanged: (Bool) -> Void = { _ in }
    var onTap: () -> Void = {}
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: video.thumbnail) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(white: 0.2)
            }
            .frame(height: 140)
            .cornerRadius(8)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(hovering ? 0.3 : 0), lineWidth: 2)
            )

            Text(video.title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Text(video.channel)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(10)
        .background(Color(white: hovering ? 0.16 : 0.12))
        .cornerRadius(10)
        .scaleEffect(hovering ? 1.04 : 1)
        .animation(.easeOut(duration: 0.2), value: hovering)
        .onHover { h in
            hovering = h
            onHoverChanged(h)
        }
        .onTapGesture {
            onTap()
        }
        .contentShape(Rectangle())
    }
}

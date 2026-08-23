import SwiftUI

struct CommentRow: View {
    @ObservedObject var vm: VideoViewModel
    let comment: VideoComment

    private var ref: ChannelRef {
        ChannelRef(name: comment.author, url: comment.authorURL, avatar: comment.avatar)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: comment.avatar) { image in
                image.resizable()
            } placeholder: {
                Color(white: 0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .onHover { h in
                if h { vm.hoveredUser = ref }
                else if vm.hoveredUser == ref { vm.hoveredUser = nil }
            }
            .onTapGesture { vm.showProfilePinned(ref) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.author)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                        .onHover { h in
                            if h { vm.hoveredUser = ref }
                            else if vm.hoveredUser == ref { vm.hoveredUser = nil }
                        }
                        .onTapGesture { vm.showProfilePinned(ref) }

                    Text(comment.timeText)
                        .font(.caption).foregroundColor(.gray)
                }

                Text(comment.text)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(Color(white: 0.85))

                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup").font(.caption)
                    Text("\(comment.likes)").font(.caption)
                }
                .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

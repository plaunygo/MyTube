import SwiftUI

struct WatchView: View {
    @ObservedObject var vm: VideoViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar

            MPVContainerView(player: vm.mainPlayer)
                .frame(height: 420)
                .background(Color.black)
                .overlay {
                    if let err = vm.playbackError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(12)
                    }
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    infoBlock
                    commentsBlock
                }
                .padding(20)
            }
        }
        .background(Color(white: 0.08))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { vm.backToBrowse() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color(white: 0.15))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Text(vm.current?.title ?? "")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.05))
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vm.current?.title ?? "")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                if let cur = vm.current {
                    let ref = cur.channelRef
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(white: 0.25))
                            .frame(width: 28, height: 28)
                        Text(ref.name)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(Color(white: 0.8))
                            .onHover { h in
                                if h { vm.hoveredUser = ref }
                                else if vm.hoveredUser == ref { vm.hoveredUser = nil }
                            }
                            .onTapGesture { vm.showProfilePinned(ref) }
                    }
                }

                Spacer()

                Button { vm.downloadCurrent() } label: {
                    if let p = vm.downloadProgress {
                        HStack(spacing: 8) {
                            ProgressView(value: p).frame(width: 90)
                            Text("\(Int(p * 100))%")
                                .font(.caption).monospacedDigit()
                        }
                    } else {
                        Label("Скачать", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(white: 0.18))
                .cornerRadius(8)
                .disabled(vm.downloadProgress != nil)
            }
        }
    }

    @ViewBuilder
    private var commentsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Комментарии")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)

            if vm.commentsLoading && vm.visibleComments.isEmpty {
                ProgressView().padding()
            } else if vm.visibleComments.isEmpty {
                Text("Комментарии отключены или недоступны")
                    .font(.caption).foregroundColor(.gray)
            } else {
                ForEach(vm.visibleComments) { comment in
                    CommentRow(vm: vm, comment: comment)
                        .onAppear {
                            if comment.id == vm.visibleComments.last?.id {
                                vm.loadMoreComments()
                            }
                        }
                }

                if vm.commentsLoading {
                    ProgressView().padding()
                } else if vm.visibleComments.count < vm.totalComments || vm.hasMoreComments {
                    Text("Показать ещё…")
                        .font(.caption).foregroundColor(.gray)
                        .onAppear { vm.loadMoreComments() }
                }
            }
        }
    }
}

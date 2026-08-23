import SwiftUI
import Combine

struct BrowseView: View {
    @ObservedObject var vm: VideoViewModel
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            CustomMenuBar()
            searchBar

            ScrollView {
                if vm.loading && vm.videos.isEmpty {
                    ProgressView()
                        .padding(80)
                } else if vm.videos.isEmpty {
                    Text("Ничего не найдено.\nВведите запрос и нажмите Enter — или вставьте ссылку YouTube.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(80)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                        ForEach(vm.videos) { video in
                            VideoCard(video: video) { h in
                                if h { vm.hoveredVideo = video }
                                else if vm.hoveredVideo == video { vm.hoveredVideo = nil }
                            } onTap: {
                                vm.open(video)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(white: 0.08))
        .contentShape(Rectangle())
        .onTapGesture { focused = false }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Поиск или ссылка YouTube", text: $query)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { vm.search(query: query) }
            Spacer()
            Text("Enter поиск · ⌘F · Space превью/пауза · ←→ ↑↓ · Esc")
                .font(.caption).foregroundColor(.gray)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(white: 0.13))
        .cornerRadius(10)
        .padding([.horizontal, .top], 16)
    }
}

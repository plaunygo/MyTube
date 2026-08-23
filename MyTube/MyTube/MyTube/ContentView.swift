import SwiftUI

struct ContentView: View {
    @StateObject private var vm = VideoViewModel()

    var body: some View {
        ZStack {
            Group {
                switch vm.mode {
                case .browse: BrowseView(vm: vm)
                case .watch:  WatchView(vm: vm)
                }
            }

            if let profile = vm.profile {
                ProfileOverlay(profile: profile) { vm.closeProfile() }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color(white: 0.08))
        .preferredColorScheme(.dark)
    }
}

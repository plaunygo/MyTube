import SwiftUI

struct CustomMenuBar: View {
    var body: some View {
        HStack(spacing: 24) {
            Text("MyTube")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "gearshape")
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(white: 0.05))
        .overlay(Divider(), alignment: .bottom)
    }
}

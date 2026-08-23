import SwiftUI

struct CustomMenuBar: View {
    @StateObject private var auth = AuthManager.shared
    @State private var showLogin = false
    
    var body: some View {
        HStack(spacing: 24) {
            Text("MyTube")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)

            Spacer()
            
            if auth.isLoggedIn {
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.green)
                    Text(auth.username ?? "Пользователь")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Button(action: { auth.logout() }) {
                    Text("Выйти")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showLogin = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "key")
                        Text("Войти")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "gearshape")
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color(white: 0.05))
        .overlay(Divider(), alignment: .bottom)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

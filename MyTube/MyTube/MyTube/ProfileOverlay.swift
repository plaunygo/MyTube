import SwiftUI

struct ProfileOverlay: View {
    let profile: ChannelProfile
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    AsyncImage(url: profile.avatar) { image in
                        image.resizable()
                    } placeholder: {
                        Color(white: 0.25)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)

                        if let joined = profile.joined {
                            Label(joined, systemImage: "calendar")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                        if let country = profile.country {
                            Label(country, systemImage: "globe")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2).foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(Color(white: 0.8))
                        .lineLimit(4)
                }

                if !profile.videos.isEmpty {
                    Text("Недавние видео")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 4)

                    ForEach(profile.videos) { v in
                        HStack(spacing: 10) {
                            AsyncImage(url: v.thumbnail) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(white: 0.2)
                            }
                            .frame(width: 96, height: 54)
                            .cornerRadius(6)
                            .clipped()

                            Text(v.title)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(Color(white: 0.85))
                                .lineLimit(2)

                            Spacer()
                        }
                    }
                }
            }
            .padding(22)
            .frame(width: 480)
            .background(Color(white: 0.12))
            .cornerRadius(16)
            .shadow(radius: 30)
        }
    }
}

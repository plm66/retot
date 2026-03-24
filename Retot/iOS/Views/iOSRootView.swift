import SwiftUI

struct iOSRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Retot")
                    .font(.largeTitle.bold())

                Text("Coming soon on iOS")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Retot")
        }
    }
}

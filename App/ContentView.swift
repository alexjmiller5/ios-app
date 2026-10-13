import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("CHANGEME")
                .font(.title)
            Spacer()
            VersionLabel()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

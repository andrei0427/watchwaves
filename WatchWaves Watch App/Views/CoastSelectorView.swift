import SwiftUI

struct CoastSelectorView: View {
    @Bindable var viewModel: WaveViewModel

    var body: some View {
        List {
            Section("Detection Mode") {
                Button {
                    viewModel.preferences.manualCoastDirection = nil
                } label: {
                    HStack {
                        Image(systemName: "location")
                        Text("Auto-detect")
                        Spacer()
                        if viewModel.preferences.isAutoDetect {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }

        }
        .navigationTitle("Coast")
    }
}

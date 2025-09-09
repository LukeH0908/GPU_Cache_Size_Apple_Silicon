

import SwiftUI

struct ContentView: View {
    @StateObject private var renderer = try! Renderer()
    @State private var results: String = "Press 'Run Test' to begin..."
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("GPU Cache Line Size Experiment")
                .font(.title)

            ScrollView {
                Text(results)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .border(Color.gray, width: 1)


            Button(action: {
                runTest()
            }) {
                if isRunning {
                    ProgressView()
                        .padding(.horizontal)
                    Text("Testing...")
                } else {
                    Text("Run Test")
                }
            }
            .disabled(isRunning)
            .padding()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }

    private func runTest() {
        isRunning = true
        results = "Starting test...\nThis may take a few seconds.\n\n"
        DispatchQueue.global(qos: .userInitiated).async {
            let testResults = renderer.runExperiment()
            DispatchQueue.main.async {
                results = testResults
                isRunning = false
            }
        }
    }
}

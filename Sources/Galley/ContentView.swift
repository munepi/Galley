import SwiftUI
import PDFKit
import Combine

struct PDFKitView: NSViewRepresentable {
    let url: URL
    @Binding var reloadTrigger: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        updateDocument(pdfView)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        updateDocument(nsView)
    }

    private func updateDocument(_ pdfView: PDFView) {
        let currentDestination = pdfView.currentDestination
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            if let dest = currentDestination {
                pdfView.go(to: dest)
            }
        }
    }
}

struct ContentView: View {
    let pdfURL: URL
    @State private var reloadTrigger = 0
    @State private var timer: AnyCancellable?

    var body: some View {
        PDFKitView(url: pdfURL, reloadTrigger: $reloadTrigger)
            .onAppear {
                startMonitoring()
            }
    }

    func startMonitoring() {
        let path = pdfURL.path
        let fileManager = FileManager.default
        var lastUpdate = (try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? Date()

        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard let attributes = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attributes[.modificationDate] as? Date else { return }
                
                if modDate > lastUpdate {
                    lastUpdate = modDate
                    reloadTrigger += 1
                }
            }
    }
}

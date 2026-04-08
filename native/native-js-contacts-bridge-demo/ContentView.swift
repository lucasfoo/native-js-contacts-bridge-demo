import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let handler = context.coordinator.handler
        for name in handler.allHandlerNames {
            config.userContentController.addScriptMessageHandler(
                handler,
                contentWorld: .page,
                name: name
            )
        }
        let webView = WKWebView(frame: .zero, configuration: config)

        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebApp") {
            let webAppDir = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: webAppDir)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator {
        let handler: WebViewMessageHandler

        init() {
            handler = WebViewMessageHandler()
            handler.addDelegate(ContactsMessageDelegate())
            handler.addDelegate(StressTestMessageDelegate())
            handler.addDelegate(OptimizedContactsMessageDelegate())
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}

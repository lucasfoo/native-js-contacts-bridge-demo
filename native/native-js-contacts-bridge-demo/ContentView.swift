import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let handler = context.coordinator.handler
        for name in handler.allHandlerNames {
            config.userContentController.addScriptMessageHandler(
                handler,
                contentWorld: .page,
                name: name
            )
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
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
        WebView(url: URL(string: "http://localhost:5173")!)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}

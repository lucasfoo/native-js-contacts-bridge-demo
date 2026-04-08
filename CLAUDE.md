# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Demo project to display contacts in a React webview using WKWebView's native bridge to fetch contacts via iOS native APIs. Focus is on simplicity and performance debugging (showing timing/performance metrics in the webview).

## Project Structure

- **`/web`** - React + Vite + Cloudflare Workers app
- **`/native`** - iOS SwiftUI app (Xcode project)
- **`/scripts`** - Python utilities (test contact generation)

## Commands

### Web (run from `/web` directory)

```bash
npm run dev        # Start Vite dev server with HMR
npm run build      # TypeScript compile + Vite build
npm run lint       # ESLint
npm run preview    # Build and preview production bundle
npm run deploy     # Build and deploy to Cloudflare Workers
npm run cf-typegen # Generate Cloudflare Workers types
```

### iOS

Open `/native/native-js-contacts-bridge-demo.xcodeproj` in Xcode. Build and run on simulator or device.

### Updating Bundled Web App

After making web changes, rebuild and copy into the iOS project:

```bash
cd web && npm run build && rm -rf ../native/WebApp && cp -r dist/client ../native/WebApp
```

## Architecture

### Web Layer
- React 19 SPA with Vite bundling and HashRouter (Home, Contacts list, Contact detail pages)
- Tailwind CSS with shadcn UI components and Geist font
- Vite configured with `base: './'` for relative asset paths (required for local file:// loading)
- Cloudflare Workers backend (`/web/worker/index.ts`) handles `/api/*` routes
- Can also be deployed as Cloudflare Pages with Workers for API

### Native Layer
- SwiftUI app hosting WKWebView (`ContentView.swift`)
- **Web app is bundled locally** — built JS/CSS/HTML from `web/dist/client/` is copied to `native/native-js-contacts-bridge-demo/WebApp/` and loaded via `loadFileURL` (no server required)
- `WKScriptMessageHandlerWithReply` with async delegate pattern (`WebViewMessageHandler.swift`)
- `ContactsService.swift` — CNContactStore integration with off-main-thread fetching
- `StressTestService.swift` — bulk contact generation/cleanup for load testing (batched in groups of 100)

### Bridge Pattern
The native bridge uses `WKScriptMessageHandlerWithReply` for reply-based async communication:
1. JS calls `window.webkit.messageHandlers.<name>.postMessage(payload)` and awaits the reply
2. Swift receives message, dispatches to the appropriate delegate, and returns the result
3. Three bridge endpoints:
   - `getContacts` — fetches device contacts with auth + fetch timing
   - `generateContacts` — creates test contacts (count, prefix params)
   - `cleanupContacts` — removes test contacts by prefix

## iOS Threading

CNContactStore methods (`enumerateContacts`, `execute`) must NOT run on the main thread — they trigger the warning "This method should not be called on the main thread as it may lead to UI unresponsiveness." Use `withCheckedThrowingContinuation` + `DispatchQueue.global(qos: .userInitiated)` to ensure they run off-main. `Task.detached` alone is not sufficient as Swift concurrency doesn't guarantee a specific thread.

## Performance Debugging Focus

Timing metrics are captured and displayed in the webview UI:
- Native auth time, native fetch time, native total time
- Bridge round-trip time
- React render time
- Filter time + result count

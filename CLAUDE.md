# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Demo project to display contacts in a React webview using WKWebView's native bridge to fetch contacts via iOS native APIs. Focus is on simplicity and performance debugging (showing timing/performance metrics in the webview).

## Project Structure

- **`/web`** - React + Vite + Cloudflare Workers app
- **`/native`** - iOS SwiftUI app (Xcode project)

## Commands

### Web (run from `/web` directory)

```bash
npm run dev        # Start Vite dev server with HMR
npm run build      # TypeScript compile + Vite build
npm run lint       # ESLint
npm run preview    # Build and preview production bundle
npm run deploy     # Build and deploy to Cloudflare Workers
```

### iOS

Open `/native/native-js-contacts-bridge-demo.xcodeproj` in Xcode. Build and run on simulator or device.

## Architecture

### Web Layer
- React 19 SPA with Vite bundling
- Cloudflare Workers backend (`/web/worker/index.ts`) handles `/api/*` routes
- Deployed as Cloudflare Pages with Workers for API

### Native Layer (to be implemented)
- SwiftUI app hosting WKWebView
- WebKit message handlers for JS-to-native communication
- Contacts framework integration for fetching device contacts

### Bridge Pattern (to be implemented)
The native bridge will use `WKScriptMessageHandler` to expose native contacts to JS:
1. JS calls `window.webkit.messageHandlers.<name>.postMessage()`
2. Swift receives message, fetches contacts via CNContactStore
3. Swift evaluates JS callback with serialized contact data

## iOS Threading

CNContactStore methods (`enumerateContacts`, `execute`) must NOT run on the main thread — they trigger the warning "This method should not be called on the main thread as it may lead to UI unresponsiveness." Use `withCheckedThrowingContinuation` + `DispatchQueue.global(qos: .userInitiated)` to ensure they run off-main. `Task.detached` alone is not sufficient as Swift concurrency doesn't guarantee a specific thread.

## Performance Debugging Focus

When implementing, include timing metrics for:
- Time to request contacts from native
- Serialization/deserialization time
- Render time in React
- Display these metrics in the webview UI

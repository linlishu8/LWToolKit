# LWToolKit

A modular toolbox for iOS apps with **Core**, **Media**, **UI**, and **Analytics** building blocks.

## Modules
- **LWCore**: debouncer, throttler, rate limiter, task queue with retries, reachability, keychain, memory/disk cache helpers, feature flags, A/B test, errors, localization, privacy & update check, deep link router, performance metrics, notifications.
- **LWMedia**: image loader & media/document pickers.
- **LWUI**: SwiftUI toast & alert helpers.
- **LWAnalytics**: logger & event tracker.

## Requirements
- iOS 14+
- Swift 5.9+

## Usage (SPM)
Add the package and select the products you need:
```swift
import LWCore
import LWMedia
import LWUI
import LWAnalytics
```

See `Examples/LWToolDemos` for runnable demos.

### Example App linking
In Xcode, select the `LWToolDemos` project, go to **Package Dependencies** ➝ **+** ➝ **Add Local...**, choose the repo root containing `Package.swift`, then add products `LWCore`, `LWMedia`, `LWUI`, `LWAnalytics` to the `LWToolDemos` target.

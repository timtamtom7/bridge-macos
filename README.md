# Bridge

A macOS sync and cache bridge — keeps local data coherent across devices with health insights on top.

## What it does

- Device and contact sync
- cache management
- skeleton loading states

## Targets

- macOS menu bar

## Structure

Key types:

- ``BridgeStore``
- ``CacheManager``
- ``ContactService``
- ``DeviceService``
- ``HealthInsightsEngine``
- ``CloudStorageManager``
- ``SubscriptionManager``

A shared pattern across this batch: `APIService` + `CloudStorageManager` + a store, with accessibility extensions and a `PrivacyInfo.xcprivacy` manifest.

## Status

Apple-platform experiment built to explore what an AI coding agent could produce for a native app. Not actively maintained.

Xcode projects here were generated with XcodeGen (`project.yml`) unless noted; open the `.xcodeproj` directly.

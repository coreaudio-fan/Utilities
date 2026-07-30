# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## Purpose

`Utilities` collects general-purpose utility code meant to be shared across projects. It builds `Utilities.framework` plus a test bundle. See `~/.claude/CLAUDE.md` for the global style guide.

## Build and Test

```sh
# Build the framework (Debug)
xcodebuild -project Utilities.xcodeproj -scheme Framework -configuration Debug build

# Build the framework (Release)
xcodebuild -project Utilities.xcodeproj -scheme Framework -configuration Release build

# Run the tests
xcodebuild -project Utilities.xcodeproj -scheme Framework -configuration Debug test
```

`Framework` is the only scheme, and it is **shared** — tracked at `Utilities.xcodeproj/xcshareddata/xcschemes/Framework.xcscheme`, so it exists in a fresh clone and in CI instead of being synthesized per-user. Its test action builds `Framework` and runs the `Tests` bundle, so the one scheme covers build, test, analyze, profile, and archive.

Because a shared scheme exists, xcodebuild no longer synthesizes per-target schemes — `-scheme Tests` does not resolve. Use `-scheme Framework` for every action.

## Architecture

Two targets. Target names are generic and match the `Config/` filenames rather than the products they build:

| Target | Product | Notes |
|---|---|---|
| `Framework` | `Utilities.framework` | The shared code. Builds from `Source/` |
| `Tests` | `Utilities Tests.xctest` | Depends on and links `Framework`. Builds from `Tests/` |

Current contents: `Source/SerialNumber.swift` (unique serial numbers: the `SerialNumberValue` generation protocol, the `SerialNumber` wrapper, and stock conformances for `UInt64` and Foundation's `UUID` — the latter under `#if canImport(Foundation)`, because the DriverKit SDK has no Foundation and `driverkit` is deliberately supported). `Documentation.docc/` is the DocC catalog, kept deliberately thin — symbols are documented at their declarations, and the catalog carries only what source comments cannot express, such as the module landing page.

### Languages

The framework is configured to host **C, C++, Objective-C, and Swift**, not Swift alone. `Source/` currently contains only Swift, but the build settings are deliberately broader than its present contents: `GCC_C_LANGUAGE_STANDARD = gnu23`, `CLANG_CXX_LANGUAGE_STANDARD = gnu++23`, a large Objective-C and C++ warning and static-analyzer allowlist, `MODULE_VERIFIER_SUPPORTED_LANGUAGES = c c++`, DocC C++ and Objective-C extraction, and a Headers build phase on the `Framework` target.

Do not read the current file list as the project's language scope, and do not prune C, C++, or Objective-C settings as dead weight. That includes `driverkit` in `SUPPORTED_PLATFORMS`, which is reachable precisely because DriverKit builds C++.

### Adding files

`Source/`, `Tests/`, and `Config/` are `PBXFileSystemSynchronizedRootGroup`s (`objectVersion = 77`). Files are picked up by folder membership — **drop a file into the directory and it joins the target with no `project.pbxproj` edit**. This is also why XCODE-1 (navigator mirrors the filesystem) holds by construction here; there is no way to create a virtual group that diverges from disk.

The one exception is `Documentation.docc`, which is an explicit `PBXBuildFile` in the Framework's Sources phase. That is normal for DocC catalogs.

### Build settings (`Config/`)

All build settings live in `.xcconfig` files. The `XCBuildConfiguration` entries in `project.pbxproj` are empty apart from one override noted below, and they reference these files through `baseConfigurationReferenceAnchor` + `baseConfigurationReferenceRelativePath`.

| File | Scope |
|---|---|
| `Project-Common.xcconfig` | Everything shared project-wide: language standards, the full warning allowlist, static analyzer, DocC, Swift language mode and concurrency |
| `Project-Debug.xcconfig` / `Project-Release.xcconfig` | `#include` Common, then per-configuration overrides (optimization, testability, dSYM, stripping) |
| `Framework-Common.xcconfig` | Framework target: deployment targets, supported platforms, packaging, bundle ID, dylib install name, module verifier |
| `Framework-Debug.xcconfig` / `Framework-Release.xcconfig` | `#include` Framework-Common; no overrides yet |
| `Tests-Common.xcconfig` | Test bundle: deployment targets, packaging, bundle ID |
| `Tests-Debug.xcconfig` / `Tests-Release.xcconfig` | `#include` Tests-Common; no overrides yet |

When changing a build setting, edit the appropriate `.xcconfig` rather than Xcode's "Build Settings" tab — anything set in the UI gets written back as an inline override in `project.pbxproj` and silently shadows the xcconfig value.

`DEVELOPMENT_TEAM` was previously set inline in the two project-level `XCBuildConfiguration`s as well as in `Project-Common.xcconfig`. The inline copies have been removed, so every `buildSettings` dict in `project.pbxproj` is now empty and the xcconfigs are the sole source of truth. If an inline override reappears there, Xcode's UI put it back.

Settings worth knowing about:

- `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` and `GCC_TREAT_WARNINGS_AS_ERRORS = YES` — any new warning fails the build.
- `SWIFT_STRICT_CONCURRENCY = complete` with `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`.
- `SWIFT_DISABLE_SAFETY_CHECKS = NO` in `Project-Common.xcconfig`, stated explicitly even though `NO` is Xcode's default. Setting it to `YES` maps to `-remove-runtime-asserts`, which strips runtime asserts in optimized builds; it was `YES` here unintentionally. Leave it `NO` so bounds checks, overflow traps, and preconditions survive in Release.
- `OTHER_DOCC_FLAGS = --warnings-as-errors --analyze` — DocC runs inside every build (`RUN_DOCUMENTATION_COMPILER = YES`), so documentation warnings fail the build and symbol links in doc comments are load-bearing; `--analyze` additionally surfaces note-level findings, which report but cannot fail.
- `SUPPORTED_PLATFORMS` covers every Apple platform including `driverkit`, with `DRIVERKIT_DEPLOYMENT_TARGET` set alongside it. This is deliberate — see Languages above before assuming any of it is prunable.
- `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` — library evolution and a stable ABI, with a `.swiftinterface` emitted. Deliberate; do not assume the Xcode-subproject model below makes it redundant.

## Testing

The suite uses **swift-testing**, not XCTest — `import Testing`, `struct` suites, `@Test` functions, `#expect` macros. There is no `XCTestCase` anywhere and no `import XCTest`. New tests should follow suit. Use `try #require(...)` rather than force-unwrapping when a test needs to unwrap.

The target is still a `com.apple.product-type.bundle.unit-test` bundle, so the runner reports results in XCTest-style output.

### Suites, and the import convention

| File | Suite | Purpose |
|---|---|---|
| `Tests/SerialNumberTests.swift` | `SerialNumberTests` | Behaviour of `SerialNumber` — uniqueness (serial and concurrent), copy propagation, creation order, custom conformers |
| `Tests/SerialNumberAPITests.swift` | `SerialNumberAPITests` | That `SerialNumber`'s and `SerialNumberValue`'s published API is reachable from another module |

**All use a plain `import Utilities`, and that is deliberate.** `@testable import` makes internal declarations visible, which defeats any check that the public surface is genuinely public: the since-removed `Weak` type was once `public` with an internal initializer and referent, and its behaviour tests passed anyway because `@testable` bypassed access control. So tests are written as client code by default. `@testable` is a per-file exception, permitted only where a test cannot otherwise reach what it needs, and the file using it should state why. Nothing needs it today.

Access control is enforced at compile time, so an API regression **fails the build, not a test** — which is the point of doing it this way, not a shortcoming of it. A compile-time failure is unavoidable, arrives before any test runs, and cannot be skipped or forgotten. Prefer this kind of enforcement wherever the toolchain can provide it.

Reverting `SerialNumber`'s `public init()` to `init()` yields `'SerialNumber<T>' initializer is inaccessible due to 'internal' protection level` at every construction site. Expect those errors in *both* test files, since both are clients; `SerialNumberAPITests` is where the intent is documented and where the whole published surface is covered deliberately, so that coverage cannot drift as the behaviour tests change.

## Consuming the framework

The intended model is an **Xcode subproject**: a consumer adds `Utilities.xcodeproj` to its workspace and links the `Utilities.framework` product. There is deliberately no `Package.swift` — build settings stay solely in `Config/*.xcconfig`, which SPM would not honor.

One constraint to know about: **deployment targets are 26.0 on every platform** (DriverKit 25.0), so a consumer must target macOS 26 / iOS 26 or later. Nothing in the current code requires that floor, so it could be lowered if a consumer ever needs it (`Atomic`, the earliest-available dependency, needs macOS 15).

## Toolchain floor

Developed against Xcode 26.6 / Swift 6.3.3. No current source demands a newer compiler than the `SWIFT_VERSION = 6.0` language mode implies — but note that setting is the language *mode*, not a compiler version, so it would not surface such a demand if one appeared.

## History: the removed `Weak` type

The project once shipped `Weak<T: AnyObject>`, a hashable weak-reference wrapper. Its first design hashed an `ObjectIdentifier` that outlived the referent, so a wrapper around a newly allocated object could collide with a stale wrapper whose referent's address had been recycled; its second design hashed a per-wrapper `SerialNumber<UInt64>`, which ended the collisions at the price of same-object deduplication (`Weak(x) == Weak(x)` became `false`). There was no way to preserve both properties, so the type was removed rather than kept limping. The standing conclusion: **question any use of weak references in contexts that do not natively support them** — a `Hashable` container is exactly such a context.

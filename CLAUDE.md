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

Current contents: `Source/Weak.swift` is the only utility. `Documentation.docc/` is a DocC catalog, still holding the untouched Xcode template with `@START_MENU_TOKEN@` placeholders, while `RUN_DOCUMENTATION_COMPILER = YES`.

### Languages

The framework is configured to host **C, C++, Objective-C, and Swift**, not Swift alone. `Source/` currently contains only `Weak.swift`, but the build settings are deliberately broader than its present contents: `GCC_C_LANGUAGE_STANDARD = gnu23`, `CLANG_CXX_LANGUAGE_STANDARD = gnu++23`, a large Objective-C and C++ warning and static-analyzer allowlist, `MODULE_VERIFIER_SUPPORTED_LANGUAGES = c c++`, DocC C++ and Objective-C extraction, and a Headers build phase on the `Framework` target.

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
- `SUPPORTED_PLATFORMS` covers every Apple platform including `driverkit`, with `DRIVERKIT_DEPLOYMENT_TARGET` set alongside it. This is deliberate — see Languages above before assuming any of it is prunable.
- `BUILD_LIBRARY_FOR_DISTRIBUTION = YES` — library evolution and a stable ABI, with a `.swiftinterface` emitted. Deliberate; do not assume the Xcode-subproject model below makes it redundant.

## Testing

The suite uses **swift-testing**, not XCTest — `import Testing`, `struct` suites, `@Test` functions, `#expect` macros. There is no `XCTestCase` anywhere and no `import XCTest`. New tests should follow suit. Use `try #require(...)` rather than force-unwrapping when a test needs to unwrap.

The target is still a `com.apple.product-type.bundle.unit-test` bundle, so the runner reports results in XCTest-style output.

### Suites, and the import convention

| File | Suite | Purpose |
|---|---|---|
| `Tests/WeakTests.swift` | `WeakTests` | Behaviour of `Weak` — equality, hashing, container semantics, referent lifetime |
| `Tests/WeakAPITests.swift` | `WeakAPITests` | That the published API is reachable and usable from another module |

**Both use a plain `import Utilities`, and that is deliberate.** `@testable import` makes internal declarations visible, which defeats any check that the public surface is genuinely public: `Weak` was once `public` with an internal `init(_:)` and an internal `value`, and the behaviour tests passed anyway because `@testable` bypassed access control. So tests are written as client code by default. `@testable` is a per-file exception, permitted only where a test cannot otherwise reach what it needs, and the file using it should state why. Nothing needs it today.

Access control is enforced at compile time, so an API regression **fails the build, not a test** — which is the point of doing it this way, not a shortcoming of it. A compile-time failure is unavoidable, arrives before any test runs, and cannot be skipped or forgotten. Prefer this kind of enforcement wherever the toolchain can provide it.

Reverting `public init(_:)` to `init(_:)` yields `'Weak<T>' initializer is inaccessible due to 'internal' protection level` at every construction site. Expect those errors in *both* test files, since both are clients; `WeakAPITests` is where the intent is documented and where the whole published surface is covered deliberately, so that coverage cannot drift as the behaviour tests change.

`badUsage()` in `Tests/WeakTests.swift` has no executable body — its content is entirely commented out. It can never fail, and is kept deliberately as a documentation stub. What it documents (that `Weak<T>(nil)` does not compile) is a compile-time property swift-testing cannot express.

## Consuming the framework

The intended model is an **Xcode subproject**: a consumer adds `Utilities.xcodeproj` to its workspace and links the `Utilities.framework` product. There is deliberately no `Package.swift` — build settings stay solely in `Config/*.xcconfig`, which SPM would not honor.

One constraint to know about: **deployment targets are 26.0 on every platform** (DriverKit 25.0), so a consumer must target macOS 26 / iOS 26 or later. Nothing in the current code requires that floor — `weak let` is a compiler requirement, not a runtime one — so it could be lowered if a consumer ever needs it.

`Weak`'s public surface is `init(_:)`, `value`, `==`, and `hash(into:)`. The `id` backing equality is deliberately internal, being an implementation detail of the identity design described below.

## Toolchain floor

`Source/Weak.swift` uses `weak let`, which requires **Swift 6.2+** (SE-0481). It will not compile on Xcode 16.x. Note that `SWIFT_VERSION = 6.0` in `Project-Common.xcconfig` is the language *mode*, not the compiler version — it does not lower this floor. SE-0481 adds no runtime requirement, so `weak let` does not constrain the deployment target.

Developed against Xcode 26.6 / Swift 6.3.3.

## Notes on `Weak`

`Weak<T: AnyObject>` wraps a weak reference so it can live in a `Set` or dictionary. It stores the `weak let` reference alongside an `ObjectIdentifier` captured during `init` — the one moment a strong reference is guaranteed to exist. Equality and hashing use only that identifier, so a `Weak` keeps its identity and stays findable in a container after its referent deallocates. `Sendable` is conditional on `T: Sendable`.

**Accepted caveat:** because the identifier outlives the referent and object addresses get reused, a `Weak` wrapping a brand-new object can compare equal to — and hash the same as — a stale `Weak` whose referent is gone. Inserting the new wrapper into a `Set` that holds the stale one silently no-ops. This is a deliberate tradeoff, not a bug: stable-after-death identity and reuse-immunity cannot coexist without breaking same-object deduplication. Do not "fix" it without revisiting that decision.

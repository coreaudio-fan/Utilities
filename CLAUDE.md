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

Current contents: `Source/IDFactory.swift` (see IDFactory below). `Documentation.docc/` is the DocC catalog, kept deliberately thin — symbols are documented at their declarations, and the catalog carries only what source comments cannot express, such as the module landing page.

### IDFactory

`IDFactory<ID>` hands out unique unsigned identifiers from an atomic counter. Identifiers are unique to the **instance** that issued them, so each factory is its own namespace.

Three properties look odd and are each forced rather than chosen. Do not "clean them up" without reading this first.

- **`makeIdentifier()` is six concrete overloads**, one per unsigned width, with identical bodies. `Atomic<Value>` publishes its arithmetic (`add`, `subtract`, `min`, …) only through same-type extensions such as `extension Atomic where Value == UInt64`. A same-type constraint on a type *parameter* eliminates that parameter, so no protocol conformance can reach those methods — constraining `ID` to a marker protocol fails with `requires the types 'ID' and 'Int' be equivalent`. The consequence for callers: an unsupported width is rejected at the `makeIdentifier()` call site rather than at the declaration. Collapsing this to one generic method requires a shim protocol that re-declares each operation *and* bakes in its memory ordering, because orderings cannot be forwarded through a protocol requirement (`ordering argument must be a static method or property of 'AtomicUpdateOrdering'`) without the underscored `@_semantics("atomics.requires_constant_orderings")` attribute.
- **It is a class, not a struct.** `Atomic` is not copyable, which forces `~Copyable` onto a struct and propagates to every consumer — each sharing site then needs a reference-type box. Noncopyability stops at a reference boundary, so a class shares one counter with no wrapper. The `Sendable` conformance is compiler-checked, not `@unchecked`.
- **Overflow traps.** `add(_:ordering:)` aborts on overflow rather than wrapping. Wrapping would silently reissue identifiers and break the contract; exhausting the space implies a bug upstream, which is not a condition a caller can act on. This is deliberate, not an oversight, and it is why `SWIFT_DISABLE_SAFETY_CHECKS = NO` matters below.

The generic parameter is also a deliberate learning vehicle for Swift's generics — do not propose collapsing it to a concrete `UInt64` type.

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

### Writing documentation comments

Because DocC runs inside every build with `--warnings-as-errors`, doc comments are compiled artifacts and a bad one fails the build. What that does and does not protect, all verified against this project:

- **Double backticks are symbol links and are build-enforced.** They must resolve, and resolve *uniquely*. ``makeIdentifier()`` does not: with six overloads it fails with `'makeIdentifier()' is ambiguous at '/Utilities/IDFactory'`. DocC prints a hash suffix per overload (``makeIdentifier()-2fgh1``), but those derive from the symbol's USR and change when a signature changes. Return-type disambiguation does not help here — all six declare `-> ID`, and DocC's signature disambiguation does not reach into `where` clauses.
- **Single backticks are code voice and carry no build risk.** Use them for any symbol you are merely naming rather than linking. This is why `Identifiable` and `ID` appear in single backticks in `IDFactory.swift`.
- **Standard library symbols cannot be linked at all.** ``Identifiable`` fails with `doesn't exist at '/Utilities/IDFactory'`, and module qualification does not help — DocC reads ``Swift/Identifiable`` as a path *inside* this bundle (`/Utilities/Swift`). The build passes docc only this framework's symbol graph, so there is nothing else to resolve against. A plain Markdown link to `developer.apple.com` works if a link is genuinely wanted.
- **Markdown works; HTML does not.** Headings, bold, italic, lists, fenced code blocks, thematic breaks, and GFM tables and strikethrough all render as proper nodes. Raw HTML is silently stripped — tags vanish, text survives, no warning. Blockquotes are silently promoted to Note asides.
- **The enforcement is asymmetric.** A broken *internal* symbol link fails the build immediately; a broken *external* URL or malformed Markdown fails silently and forever. The build protects the links, not the prose.

## Testing

The suite uses **swift-testing**, not XCTest — `import Testing`, `struct` suites, `@Test` functions, `#expect` macros. There is no `XCTestCase` anywhere and no `import XCTest`. New tests should follow suit. Use `try #require(...)` rather than force-unwrapping when a test needs to unwrap.

The target is still a `com.apple.product-type.bundle.unit-test` bundle, so the runner reports results in XCTest-style output.

### Suites, and the import convention

| File | Suite | Purpose |
|---|---|---|
| `Tests/IDFactoryTests.swift` | `IDFactoryTests` | Behaviour of `IDFactory` — uniqueness (serial and concurrent), monotonicity, sentinel exclusion, reference sharing versus separate instances, all six widths, `UInt8` exhaustion |
| `Tests/IDFactoryAPITests.swift` | `IDFactoryAPITests` | That `IDFactory`'s published API is reachable from another module |

Each width needs its own test because `makeIdentifier()` is six concrete overloads rather than one generic method — no single generic helper can drive them all. The `UInt8` exhaustion test stops at `UInt8.max` deliberately: the next call computes 256 and traps, and a trap cannot be caught by the test runner, so that boundary is documented in a comment rather than exercised.

**All use a plain `import Utilities`, and that is deliberate.** `@testable import` makes internal declarations visible, which defeats any check that the public surface is genuinely public: the since-removed `Weak` type was once `public` with an internal initializer and referent, and its behaviour tests passed anyway because `@testable` bypassed access control. So tests are written as client code by default. `@testable` is a per-file exception, permitted only where a test cannot otherwise reach what it needs, and the file using it should state why. Nothing needs it today.

Access control is enforced at compile time, so an API regression **fails the build, not a test** — which is the point of doing it this way, not a shortcoming of it. A compile-time failure is unavoidable, arrives before any test runs, and cannot be skipped or forgotten. Prefer this kind of enforcement wherever the toolchain can provide it.

Reverting `IDFactory`'s `public init()` to `init()` yields `'IDFactory<ID>' initializer is inaccessible due to 'internal' protection level` at every construction site — 46 of them as of this writing. Expect those errors in *both* test files, since both are clients; `IDFactoryAPITests` is where the intent is documented and where the whole published surface is covered deliberately, so that coverage cannot drift as the behaviour tests change.

That `public init()` exists **only** to be public. A public type's synthesized default initializer is `internal`, and there is no way to raise a synthesized initializer's access level in place, so the declaration must be written out. Its body is empty because the stored counter already carries its default value. Do not delete it as dead code.

## Consuming the framework

The intended model is an **Xcode subproject**: a consumer adds `Utilities.xcodeproj` to its workspace and links the `Utilities.framework` product. There is deliberately no `Package.swift` — build settings stay solely in `Config/*.xcconfig`, which SPM would not honor.

One constraint to know about: **deployment targets are 26.0 on every platform** (DriverKit 25.0), so a consumer must target macOS 26 / iOS 26 or later. Nothing in the current code requires that floor, so it could be lowered if a consumer ever needs it — but not below macOS 15, which is where both `Atomic` and `UInt128` become available.

## Toolchain floor

Developed against Xcode 26.6 / Swift 6.3.3. No current source demands a newer compiler than the `SWIFT_VERSION = 6.0` language mode implies — but note that setting is the language *mode*, not a compiler version, so it would not surface such a demand if one appeared.

## History: removed types

### `SerialNumber`

The project previously shipped `SerialNumber<T>` and the `SerialNumberFactory` protocol — a generic wrapper whose conformers generated their own values, with stock conformances for `UInt64` and Foundation's `UUID` (the latter under `#if canImport(Foundation)`, since the DriverKit SDK has no Foundation). `IDFactory` replaced it: the generation strategy moved out of the value type and into an explicit factory, which made the counter shareable and its uniqueness scope legible. Both `SerialNumber` test suites were removed with it.

### `Weak`

The project once shipped `Weak<T: AnyObject>`, a hashable weak-reference wrapper. Its first design hashed an `ObjectIdentifier` that outlived the referent, so a wrapper around a newly allocated object could collide with a stale wrapper whose referent's address had been recycled; its second design hashed a per-wrapper `SerialNumber<UInt64>`, which ended the collisions at the price of same-object deduplication (`Weak(x) == Weak(x)` became `false`). There was no way to preserve both properties, so the type was removed rather than kept limping. The standing conclusion: **question any use of weak references in contexts that do not natively support them** — a `Hashable` container is exactly such a context.

# AGENTS.md — Strawberry

Strawberry is a macOS menu-bar app that runs scheduled rsync backup rules when volumes mount, and organizes media into dated event folders. It is AppKit with a storyboard, and the Xcode project is maintained in Xcode (no XcodeGen).

## Commands

- `make dev`: Debug build into `build/`, then relaunch, unless a sync is running (see below).
- `make test`: run the `StrawberryTests` suite with `xcodebuild test`.
- `make publish`: Release build. `make install`: Release build installed to `/Applications`.
- `make clean`.

## Layout

- `Strawberry/App/`: `AppDelegate` and logging.
- `Strawberry/Sync/`: rule models and `Store`, `Scheduler`, `RsyncRunner`, `VolumeMonitor`, and volume helpers.
- `Strawberry/AutoMediaSync/`, `Strawberry/Media/`: automatic media import and `MediaOrganizer`.
- `Strawberry/UI/`: menu and window controllers.
- `StrawberryTests/`: XCTest suite.

## Conventions

- New source files must be added to `Strawberry.xcodeproj` (the project doesn't use synchronized folders).
- Never kill the app mid-sync. `Scheduler` writes `~/Library/Application Support/Strawberry/sync-in-progress.lock` during an rsync, and `make open` leaves the app running while it exists. Killing mid-sync makes the rule look like it loops.
- rsync rules touch user data: never add `--delete` or other destructive flags without an explicit request, and test path handling with spaces.

## Design principles

Follow the [design principles](docs/rules/design-principles.md) for any UI work.

## After changing code

1. `make test`
2. `make dev`
3. Show the changes and propose a short, one-line commit message for approval. Don't commit without it. `scripts/claude/post-turn.sh` runs steps 1 and 2 automatically.

# Countpane Portfolio Readiness - Implementation Backlog

## Goal

Make Countpane safer to evolve as a local-first macOS application and easier
to evaluate as a Senior macOS portfolio repository. The work preserves the
current no-account, no-cloud model and improves data durability, import
safety, native-widget resilience, release verification, test evidence, and
recruiter-facing documentation.

Apple Developer Program enrollment/notarization and GitHub branch-protection
configuration are explicitly out of scope for this backlog.

## Architectural decisions

- `CountdownItem` remains the single domain model. `AppModel` remains the
  `@MainActor` owner of in-memory state, and `CountdownRepository` remains the
  actor-isolated owner of SQLite I/O. Do not add parallel DTOs, stores, or a
  second persistence layer.
- SQLite is the source of truth for runtime data. A one-time database migration
  may canonicalize existing data, but old nullable/legacy runtime flows must be
  removed afterwards. JSON import accepts only the current format; do not add
  compatibility decoders for retired formats.
- Import validation belongs in `CountpaneJSONTransfer`; `SettingsView` only
  obtains security-scoped data, asks for destructive confirmation, and presents
  errors. `AppModel.replaceAll` remains the atomic persistence-before-UI swap.
- Widget positions remain `UserDefaults` UI preferences keyed by countdown ID;
  the controller must validate them against currently attached screens instead
  of duplicating positions in SQLite or view state.
- The existing SwiftPM and shell packaging path remains canonical. Add checks to
  it rather than introducing a second build system or an updater framework.
- Keep global `shared` composition only at application entry points. Any
  dependency injection added by this backlog is narrow and test-oriented, not a
  new Clean Architecture/MVVM layer.
- Do not add cloud sync, accounts, telemetry, Electron, a backend service, or a
  custom auto-updater.

## Recommended implementation order

| Order | Task | Priority | Depends on | Reason |
| ---: | --- | --- | --- | --- |
| 1 | P1-1 | P1 | - | Removes the known legacy state before migration work expands it. |
| 2 | P1-2 | P1 | P1-1 | Hardens the canonical JSON contract and atomic import path. |
| 3 | P2-1 | P2 | P1-1 | Verifies data evolution and backup safety at the repository boundary. |
| 4 | P2-2 | P2 | - | Prevents floating widgets from becoming unreachable after display changes. |
| 5 | P2-3 | P2 | P2-2 | Adds native UI and accessibility evidence after behavior is stable. |
| 6 | P2-4 | P2 | - | Makes the existing DMG path prove image integrity and install contents. |
| 7 | P2-5 | P2 | P2-3, P2-4 | Fixes maintainers' docs and shows verified behavior to recruiters. |
| 8 | P2-6 | P2 | P2-5 | Adds visual evidence for the menu-bar/widget product differentiation. |
| 9 | P3-1 | P3 | P1-2 | Narrows global-service coupling only where integration coverage needs it. |

## P1-1: Canonicalize countdown creation dates and remove the legacy flow

**Status:** ✅ Completed
**Priority:** P1  
**Depends on:** -

### Outcome

Every persisted and imported countdown has a valid creation date. The editor
no longer contains a fallback that silently treats a missing creation date as a
legacy record and assigns the save time.

### Architectural decision

`createdAt` is a required domain and SQLite value after a one-time canonical
database migration. The migration performs data preservation once for existing
`NULL` values using the explicitly documented canonicalization rule, then the
runtime model, persistence schema, JSON contract, editor fallback, and
legacy-named test are removed together. There is no continuing legacy import
or runtime branch after the migration.

### Files

- Modify `Sources/Countpane/Models/Models.swift`.
- Modify `Sources/Countpane/Services/Persistence.swift`.
- Modify `Sources/Countpane/Services/JSONTransfer.swift`.
- Modify `Sources/Countpane/Views/CountdownEditor.swift`.
- Modify `Tests/CountpaneTests/CountdownCodingTests.swift`.
- Modify `Tests/CountpaneTests/PersistenceTests.swift`.
- Modify `Tests/CountpaneTests/JSONTransferTests.swift`.
- Modify `Tests/CountpaneTests/CountdownEditorDraftTests.swift`.
- Remove the legacy fallback test and any legacy-only helper it leaves unused.

### Work

1. Define the exact deterministic date used to canonicalize historical `NULL`
   rows and document it in a migration comment/test; do not guess a historical
   date that was never stored.
2. Version SQLite schema changes and migrate an existing database transactionally
   before normal reads and writes. Preserve all countdown fields and ordering.
3. Make the domain and current JSON format require `createdAt`; reject an import
   that omits it rather than silently manufacturing a date.
4. Remove `CountdownEditorDraft.itemForSaving` legacy fallback behavior and
   replace its regression test with a required-date invariant.

### Acceptance criteria

- A current countdown always has a non-optional `createdAt` after creation,
  editing, export, import, save, and reload.
- A fixture database with the prior nullable field is upgraded once without
  losing countdowns, order, notes, themes, widget visibility, or completion
  state.
- Reopening the migrated database does not rerun or alter the migration.
- A current-format backup missing `createdAt` is rejected before replacing
  in-memory or SQLite data.
- No production code or test name refers to a legacy countdown fallback.

### Verification

```bash
swift test --filter CountdownCodingTests
swift test --filter CountdownRepositoryTests
swift test --filter CountdownEditorDraftTests
swift test --filter JSONTransferTests
swift test
git diff --check
```

### Commit

```bash
git add Sources/Countpane/Models/Models.swift Sources/Countpane/Services/Persistence.swift Sources/Countpane/Services/JSONTransfer.swift Sources/Countpane/Views/CountdownEditor.swift Tests/CountpaneTests/CountdownCodingTests.swift Tests/CountpaneTests/PersistenceTests.swift Tests/CountpaneTests/JSONTransferTests.swift Tests/CountpaneTests/CountdownEditorDraftTests.swift
git commit -m "refactor(data): Remove legacy countdown dates"
```

## P1-2: Bound and validate backup imports before replacement

**Status:** ✅ Completed
**Priority:** P1  
**Depends on:** P1-1

### Outcome

An oversized, malformed, semantically invalid, or unexpected JSON backup is
rejected with a useful message before it can replace local countdowns.

### Architectural decision

`CountpaneJSONTransfer` owns size, item-count, text-length, finite-date, ID,
and domain-invariant validation. `SettingsView` enforces the file-size bound
before decoding. `AppModel.replaceAll` remains the only destructive write path
and performs SQLite persistence before assigning `items`.

### Files

- Modify `Sources/Countpane/Services/JSONTransfer.swift`.
- Modify `Sources/Countpane/Services/AppModel.swift`.
- Modify `Sources/Countpane/Views/SettingsView.swift`.
- Modify `Tests/CountpaneTests/JSONTransferTests.swift`.
- Modify `Tests/CountpaneTests/AppModelRegressionTests.swift`.

### Work

1. Choose documented, user-appropriate limits for backup bytes, item count, and
   title/note lengths; centralize those limits in the transfer layer.
2. Reject non-finite dates and invalid completion/date relationships in addition
   to duplicate IDs, blank titles, and invalid thresholds.
3. Reject a file before decoding when its file metadata exceeds the byte limit;
   retain a decode-time guard for callers that provide `Data` directly.
4. Keep the existing confirmation alert and transactional save behavior. Add
   tests proving each rejected input leaves both the displayed list and existing
   SQLite rows untouched.

### Acceptance criteria

- A file above the documented size limit is rejected without mapping or decoding
  its contents.
- Excessive item counts, oversized text, duplicate IDs, missing required fields,
  non-finite dates, and invalid domain combinations display a transfer error.
- Unknown JSON keys do not change the interpretation of the current contract;
  missing or incompatible required data is rejected.
- A rejected import never clears or partially replaces the current list.
- A valid current-format export still imports and round-trips exactly.

### Verification

```bash
swift test --filter JSONTransferTests
swift test --filter AppModelRegressionTests
swift test
git diff --check
```

### Commit

```bash
git add Sources/Countpane/Services/JSONTransfer.swift Sources/Countpane/Services/AppModel.swift Sources/Countpane/Views/SettingsView.swift Tests/CountpaneTests/JSONTransferTests.swift Tests/CountpaneTests/AppModelRegressionTests.swift
git commit -m "fix(import): Validate backup boundaries"
```

## P2-1: Add durable migration and transfer regression fixtures

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** P1-1

### Outcome

Future schema and interchange changes have small, readable fixtures proving
that the supported migration path preserves user data and that unsupported
formats fail safely.

### Architectural decision

Fixtures are test-only inputs, not a second runtime data format. SQLite tests
exercise `CountdownRepository`; transfer fixtures exercise
`CountpaneJSONTransfer` and `AppModel.replaceAll`. Avoid snapshotting private
real-user data.

### Files

- Create `Tests/CountpaneTests/Fixtures/pre-created-at.sql`.
- Create `Tests/CountpaneTests/Fixtures/current-backup.json`.
- Create `Tests/CountpaneTests/Fixtures/unsupported-backup.json`.
- Modify `Tests/CountpaneTests/PersistenceTests.swift`.
- Modify `Tests/CountpaneTests/JSONTransferTests.swift`.
- Modify `Package.swift` only if test resources require explicit declaration.

### Work

1. Add anonymized, minimal fixtures produced from the actual preceding schema
   and current export encoder; document their purpose in the tests.
2. Assert schema version and every persisted user-facing field after migration.
3. Assert current backup compatibility, unsupported-version rejection, and no
   replacement on failure using fixture inputs.
4. Keep fixture generation reproducible and do not include local databases,
   backup titles, notes, user paths, or production artifacts.

### Acceptance criteria

- The previous-schema fixture migrates to the current schema with deterministic
  rows and ordering.
- Current JSON fixture imports unchanged; unsupported fixture is rejected.
- Fixtures contain only synthetic data and are small enough for review in Git.
- Tests do not depend on the developer's Application Support directory.

### Verification

```bash
swift test --filter CountdownRepositoryTests
swift test --filter JSONTransferTests
swift test
git diff --check
```

### Commit

```bash
git add Package.swift Tests/CountpaneTests/Fixtures/pre-created-at.sql Tests/CountpaneTests/Fixtures/current-backup.json Tests/CountpaneTests/Fixtures/unsupported-backup.json Tests/CountpaneTests/PersistenceTests.swift Tests/CountpaneTests/JSONTransferTests.swift
git commit -m "test(data): Add migration fixtures"
```

## P2-2: Restore widgets safely across display changes

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** -

### Outcome

A widget saved on a disconnected display is moved to a visible position rather
than opening off-screen. Existing valid positions remain stable.

### Architectural decision

`WidgetWindowPositionStore` keeps only persisted coordinates. The AppKit
`WidgetWindowController` determines the currently usable screen geometry and
clamps or rehomes a frame before presenting it. Do not store screen state in
SQLite or SwiftUI view state.

### Files

- Modify `Sources/Countpane/App/WidgetWindowController.swift`.
- Modify `Tests/CountpaneTests/WidgetWindowPositionStoreTests.swift`.
- Create `Tests/CountpaneTests/WidgetWindowPlacementTests.swift`.

### Work

1. Extract deterministic, AppKit-independent placement/clamping logic that can
   receive screen visible frames in tests.
2. Preserve a stored frame when it visibly intersects an attached screen;
   otherwise assign the normal cascade origin on an available screen.
3. Clamp the full widget frame inside the selected visible frame, including
   menu-bar/dock-safe bounds and the close-button hit area.
4. Retain the current single owner (`WidgetWindowController`) and no duplicate
   SwiftUI widget scene.

### Acceptance criteria

- A valid saved origin is restored without movement.
- An origin outside every supplied display is rehomed visibly.
- A partially off-screen origin is clamped so the entire widget and close
  control remain reachable.
- Initial placement continues to cascade multiple new widgets.
- Manual macOS verification covers disconnecting an external monitor, changing
  display arrangement, Spaces, and fullscreen auxiliary behavior.

### Verification

```bash
swift test --filter WidgetWindowPositionStoreTests
swift test --filter WidgetWindowPlacementTests
swift test
git diff --check
```

### Commit

```bash
git add Sources/Countpane/App/WidgetWindowController.swift Tests/CountpaneTests/WidgetWindowPositionStoreTests.swift Tests/CountpaneTests/WidgetWindowPlacementTests.swift
git commit -m "fix(widgets): Rehome offscreen panels"
```

## P2-3: Add native UI accessibility and lifecycle smoke coverage

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** P2-2

### Outcome

Critical menu-bar, editor, import, widget, keyboard, and VoiceOver behavior is
verified through the smallest viable macOS UI smoke suite plus a documented
manual physical-Mac checklist.

### Architectural decision

Keep fast domain tests in `CountpaneTests`; add a separate UI-test target only
for flows that cannot be established by unit tests. Accessibility labels remain
defined in SwiftUI views rather than duplicated in test-only wrappers.

### Files

- Create `Tests/CountpaneTests/AccessibilityContractTests.swift`.
- Create `docs/manual-macos-verification.md`.
- Modify `Sources/Countpane/Views/ActiveView.swift` only for an uncovered,
  user-visible accessibility identifier or label.
- Modify `Sources/Countpane/Views/CountdownWidgetView.swift` only for an
  uncovered, user-visible accessibility identifier or label.

### Work

1. Extend the existing SwiftPM test target with deterministic accessibility
   contract tests for duration/urgency/progress values and widget hit targets;
   do not introduce a second Xcode project or build system.
2. Add stable accessibility identifiers only to the existing active-card and
   widget-dismiss controls so a future native UI harness can target them.
3. Write a manual checklist for menu-bar reopening, editor save/discard,
   import error presentation, keyboard shortcuts, Dark Mode, Large Text/zoom,
   Reduce Motion,
   VoiceOver, multi-display, external monitor removal, and install-from-DMG.
4. Keep all test data synthetic and ensure automated tests use no developer
   Application Support database.

### Acceptance criteria

- Accessibility contract tests cover countdown duration/urgency/progress text
  and the widget close hit target.
- The manual checklist covers opening the main window from the menu bar,
  editor save/discard, import errors, and widget close/reopen behavior.
- VoiceOver can identify active countdown duration/urgency, widget dismissal,
  settings navigation, and update action without relying on visual text alone.
- Keyboard navigation reaches all primary controls with visible focus.
- Manual checklist marks device-only verification separately from CI proof.

### Verification

```bash
swift test
git diff --check
```

### Commit

```bash
git add Tests/CountpaneTests/AccessibilityContractTests.swift docs/manual-macos-verification.md Sources/Countpane/Views/ActiveView.swift Sources/Countpane/Views/CountdownWidgetView.swift
git commit -m "test(ui): Cover native accessibility flows"
```

## P2-4: Verify DMG integrity and install layout in packaging

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** -

### Outcome

Every generated DMG is verified, mounts cleanly, contains exactly Countpane.app
and the Applications alias, and is detached even when verification fails.

### Architectural decision

`Scripts/build-dmg.sh` remains the source of truth for disk-image production.
Use a cleanup-trapped temporary mount point; do not create a parallel packaging
script or alter signing/notarization scope.

### Files

- Modify `Scripts/build-dmg.sh`.
- Modify `.github/workflows/release.yml`.

### Work

1. Add `hdiutil verify` after creation and a temporary, non-interactive mount
   inspection with reliable cleanup.
2. Assert DMG contents have the expected application bundle and `/Applications`
   symlink, and no staging-only files.
3. Run the check for the universal CI image and both native release images.
4. Keep existing SHA-256 generation, dSYM comparison, architecture checks,
   size budgets, and ad-hoc signing behavior unchanged.

### Acceptance criteria

- A corrupt or invalid DMG makes the script and CI job fail.
- A valid DMG verifies, mounts, exposes only expected install contents, and
  detaches on both success and failure paths.
- arm64, x86_64, and universal artifact names remain unchanged.
- No notarization claim, credential, or Apple Developer setup is introduced.

### Verification

```bash
bash -n Scripts/build-dmg.sh Scripts/build-app.sh
./Scripts/build-dmg.sh 1.1.0 arm64
hdiutil verify dist/Countpane-1.1.0-arm64.dmg
./Scripts/measure-distribution-size.sh --architecture arm64 dist/Countpane-arm64.app dist/Countpane-1.1.0-arm64.dmg
git diff --check
```

### Commit

```bash
git add Scripts/build-dmg.sh .github/workflows/release.yml
git commit -m "ci(package): Verify DMG contents"
```

## P2-5: Repair maintainer documentation and publication handoff

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** P2-3, P2-4

### Outcome

Every README link resolves, a contributor can understand local checks and
release limits, and public documentation distinguishes verified delivery from
the intentionally deferred notarization work.

### Architectural decision

README remains product-facing. The release runbook contains maintainer actions;
CONTRIBUTING contains repository workflow. Do not copy implementation details
into several documents or claim an unperformed Gatekeeper/manual test.

### Files

- Modify `README.md`.
- Create `docs/RELEASE_CHECKLIST.md`.
- Create `CONTRIBUTING.md`.
- Modify `SECURITY.md` only if its reporting/data-handling guidance needs a link
  to the new contributor flow.

### Work

1. Restore an up-to-date release checklist at the path already linked by README,
   including required local, CI, GitHub Release, Cask, checksum, DMG integrity,
   and device-only checks.
2. Add concise contributor guidance for SwiftPM tests, packaging scripts, issue
   privacy, and no-user-data fixtures.
3. State exactly that DMGs use Hardened Runtime/ad-hoc signing and that
   notarization is intentionally not configured yet.
4. Verify every relative Markdown link and do not reintroduce deleted perimeter
   progress backlog material as a release checklist.

### Acceptance criteria

- `README.md` no longer has a broken release-checklist link.
- A new contributor can run the documented tests/build without discovering
  hidden commands.
- The checklist separates local checks, remote CI evidence, and physical-Mac
  checks.
- Documentation contains no false claim of notarization, Gatekeeper approval,
  cloud sync, telemetry, or automated user-data migration outside the code.

### Verification

```bash
rg -n 'docs/RELEASE_CHECKLIST.md|notarization|ad-hoc signing' README.md SECURITY.md CONTRIBUTING.md docs/RELEASE_CHECKLIST.md
test -f docs/RELEASE_CHECKLIST.md
git diff --check
swift test
```

### Commit

```bash
git add README.md SECURITY.md CONTRIBUTING.md docs/RELEASE_CHECKLIST.md
git commit -m "docs: Add publication handoff"
```

## P2-6: Add safe visual proof to the public README

**Status:** ✅ Completed
**Priority:** P2  
**Depends on:** P2-5

### Outcome

A recruiter can understand Countpane's product differentiation in under two
minutes from the README: dashboard, menu-bar reopening, floating widgets, and
local-first privacy are visible without exposing personal data.

### Architectural decision

Images are documentation assets, not application resources or test fixtures.
Use synthetic countdown titles/dates and store committed assets under `docs/`.
README links only to stable relative paths.

### Files

- Modify `README.md`.
- Reuse `docs/app-preview.png` and `docs/social-preview.png`; do not commit
  screenshots captured from a user's live database.

### Work

1. Add a second contextual presentation using the existing anonymized social
   crop and captions that communicate the user benefit, not merely the pixels.
2. Link the manual macOS verification checklist for runtime menu-bar/widget
   proof instead of fabricating a screenshot from a live user database.
3. Check Dark Mode readability, crop dimensions, and that committed images do
   not include account names, paths, private dates, tokens, or other personal
   data.

### Acceptance criteria

- README shows two anonymized visual assets above or adjacent to the feature
  explanation and links the runtime verification checklist.
- All displayed countdown content is synthetic and anonymized.
- Images are crisp on Retina displays, legible in GitHub's dark and light page
  themes, and have meaningful alt text.
- README's stated capabilities match the shown UI and current local-first model.

### Verification

```bash
file docs/app-preview.png docs/social-preview.png
rg -n 'app-preview|social-preview|manual-macos-verification' README.md
git diff --check
```

### Commit

```bash
git add README.md docs/app-preview.png docs/social-preview.png docs/manual-macos-verification.md
git commit -m "docs: Showcase native widget workflow"
```

## P3-1: Prove existing application-service isolation seams

**Status:** ✅ Completed
**Priority:** P3  
**Depends on:** P1-2

### Outcome

The existing injectable `AppModel` and `UpdateController` initializers have
explicit regression coverage proving isolated persistence, defaults, and update
state. Production app startup remains simple and has one authoritative service
graph.

### Architectural decision

Reuse the existing `CountdownStoring`, `AppModel` initializer, and
`UpdateController` initializer. Do not introduce screen-specific view models,
repositories beyond `CountdownStoring`, duplicate state, or an abstract
container framework when the current seams already isolate tests.

### Files

- Modify `Tests/CountpaneTests/AppModelRegressionTests.swift`.
- Modify `Tests/CountpaneTests/UpdateTests.swift`.

### Work

1. Add a regression proving two test models do not share SQLite paths or
   countdown state.
2. Add a regression proving two update controllers do not share defaults,
   timer state, or update status.
3. Leave production behavior and user-visible state unchanged; if the tests
   expose no missing seam, do not add a new abstraction.

### Acceptance criteria

- Two isolated test instances can run without sharing countdown data or update
  preferences.
- Production still has exactly one `AppModel` and one `UpdateController` owner;
  no second state source is introduced.
- No view gains a new business-logic layer solely for dependency injection.
- Existing unit, update, and lifecycle tests remain green.

### Verification

```bash
swift test --filter AppModelRegressionTests
swift test --filter UpdateTests
swift test
git diff --check
```

### Commit

```bash
git add Tests/CountpaneTests/AppModelRegressionTests.swift Tests/CountpaneTests/UpdateTests.swift
git commit -m "test(app): Prove service isolation"
```

## Final quality gate

Run after all tasks, without treating local success as proof of remote CI or a
physical Mac installation:

```bash
swift package dump-package >/dev/null
swift test
bash -n Scripts/*.sh
plutil -lint Packaging/Info.plist Packaging/Countpane.entitlements
gitleaks detect --source . --no-git --redact
gitleaks git --log-opts='--all' --redact
git diff --check
git status --short
```

Then confirm the pull-request CI and release workflow pass remotely. Perform
the manual macOS checklist on a physical machine before declaring widget,
VoiceOver, display-change, DMG-install, or Gatekeeper behavior verified.

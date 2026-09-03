# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-09-03

### Fixed

- A subscription whose schedule falls after the 10th of the month could not be
  edited at all. Firefly stamps its dates with the server's offset, so one due
  on the 27th arrives as `2026-10-27T00:00:00+01:00` and was read as an instant
  that is the 26th. That day was what the form showed, what the monthly
  repetition took its day from, and what the next save would have written back,
  so renaming a subscription sent a schedule nobody had touched, into an
  update-only rule that caps a repetition day at 10. Dates now keep the calendar
  fields the server wrote, in recurrences, bills, budget limits, piggy banks,
  opening balances and transactions alike
- Text in a field carrying a suggestions dropdown kept the previous frame
  underneath the new one until a resize or a scroll cleared it. The dropdown
  library never subscribed the field's render box to the link it holds, so the
  dropdown's geometry could change without the field beneath ever being marked
  dirty

## [0.3.1] - 2026-09-02

### Fixed

- Settings from before the name was spelled FireRaccoon are recovered rather
  than left stranded. The keys are read out of the store in use, which covers
  the web and anything else that kept its store across the rename, and fun mode
  is carried by value as well as by name. The old application support directory
  is read once, which brings back the undo history, the custom avatars and any
  backups taken before the rename. The people config and the account
  classifications are also asked for under the old name in Firefly, which is
  the only recovery a phone or a sandboxed desktop has, since the bundle
  identifier changed on both and neither can reach the store the old build
  wrote to
- People and account classifications held in Firefly never reached a fresh
  install. The read fired at the end of hydration, which runs before the
  credential read answers, so it found no connection and nothing scheduled
  another: the person picker stayed on All People however much the server held.
  Both are read again when the connection appears
- A preference Firefly has never stored read as an error rather than as unset,
  because 6.6.6 answers a name it does not hold with 401 Unauthenticated rather
  than 404. The credential is confirmed against `/api/v1/about` before a refusal
  is taken for an absence, so a first run is not reported as a rejected token
  and an expired token is not reported as an empty setting
- A refused or malformed read of either setting no longer passes in silence,
  where it looked exactly like having no connection yet. Keeping the local copy
  is still right; saying nothing about why was not

## [0.3.0] - 2026-09-02

### Added

- Backups of a Firefly ledger, from Settings or over MCP. A backup is two
  halves: FireRaccoon's own versioned snapshot, which a restore reads back, and
  Firefly's CSV export, which is the only copy of rules and budget limits an API
  client can reach. Named for the moment it was taken with the offset kept, so a
  stamp still reads a year later from a machine in another zone. Neither half
  reaches the database, the attachments or the instance key, and the manifest
  says so rather than leaving it to be discovered at restore time
- Restoring a backup, planned before anything is written. What the ledger lost
  is recreated, what differs is written over, and what was added since is left
  alone unless asked for, because that is the one step running the plan again
  cannot undo. A recreated row comes back under a new identifier, so everything
  naming the old one is repointed and the mapping is reported. A fresh backup is
  taken before it writes, and a backup taken as a different Firefly user is
  refused
- A password on a backup seals the snapshot and every CSV with AES-256-GCM under
  a PBKDF2 key, the same construction the settings export and the server's
  DATA_DIR already use. The manifest stays readable, because a list of backups
  has to be readable to be a list. Restoring, verifying or reading a file out of
  a sealed backup asks for the password
- Verifying a backup, which writes nothing: whether it is still what its
  manifest describes, down to a digest per file, and then how far the ledger has
  moved from it, counted by row
- Progress while a backup or a restore runs, counted in requests and shown as a
  bar and a percentage. A backup of a 19,420-transaction ledger takes about two
  and a half minutes, and a percentage only appears once there is one to give: a
  page walk cannot say how many pages there are until the first comes back
- Five MCP tools for all of it, so an agent can take a backup before a bulk
  change and put it back afterwards: `create_backup`, `list_backups`,
  `get_backup`, `verify_backup`, `restore_backup`. Taking, removing and
  restoring are write-gated
- Server mode keeps backups in the sealed `DATA_DIR`, reached over four backend
  routes, so every client of one server sees the same list

### Fixed

- The backup list stayed empty after an agent took one over MCP: it reads the
  same store the tools write to, and nothing told an open screen about it
- The reused passphrase dialog offered to "Export settings" when what it was
  asking for was a backup password

## [0.2.1] - 2026-08-30

### Added

- Numbers and dates can be written in conventions of their own, chosen apart
  from the language the app is in. One locale used to decide all three, so
  reading it in English imposed American amounts and American dates on someone
  who writes neither. Both default to following the language, so nothing moves
  until the setting is opened, and every option shows what it would produce
  rather than only naming itself

### Fixed

- The undo history was always empty on the web, so nothing could be undone or
  redone there and the History page listed nothing. Local history was written
  through a store whose web implementation drops every write and answers every
  read with nothing, so it was never saved and never read back. It is kept in
  local storage there now, and in a file everywhere that has one

## [0.2.0] - 2026-08-30

### Added

- Settings lists what has failed since the app started, with a button to copy
  it. A failed write used to say its piece once and vanish, and nothing kept a
  copy, so the only account of why Firefly refused something was the server's
  own log. The list holds warnings and failures, not ordinary traffic, is
  redacted on the way in and keeps an error's type rather than the error
  itself. It is never written to disk and never sent anywhere

### Fixed

- On a phone the header was laid out underneath the status bar, so the menu,
  the search field, the people selector and the undo controls sat where the
  system takes the taps. The whole top row was unusable on Android
- Choosing "All People" in the person selector did nothing. The menu reported
  that entry the same way it reports being dismissed, so the filter stayed on
  whoever was selected with no way back to everyone
- A transaction could be saved against the wrong one of a payee's two accounts.
  Firefly keeps an expense account and a revenue account under one name for the
  same counterparty, and a typed name matched whichever came first regardless
  of which end it was filling, so Firefly refused the write outright and
  nothing was saved
- A split transaction's date sat among the first split's own fields although
  one date covers the whole transaction and is written to every split
- A recurring transaction dated after the 10th of the month could not be
  edited, whatever the edit was. Firefly checks a repetition's day as a number
  no greater than 10 when updating and not when creating, so these were
  creatable and then permanently read-only through the API, as were yearly
  rules and rules on the nth weekday, whose day is not a number at all. Firefly
  only rechecks a schedule the request carries one of, so a schedule nobody
  edited is no longer sent. When the day itself is what changed and Firefly
  still refuses it, the refusal now says why, that nothing was saved, and where
  the day can be changed instead
- A spend from an account in one currency to a payee could not be saved on an
  installation whose primary currency is another. Firefly gives every account a
  currency, filling one in for the payees and other counterparties that have
  none of their own, so a euro spend on a krona installation read as a currency
  crossing and asked for a second amount. Refusing to give one blocked the save
  before it left the app, and giving one would have written a second currency
  onto a transaction with a single currency
- A refused write reported itself as a network error though Firefly had
  answered, and the recurring transaction form raised it through a SnackBar,
  which draws inside the page underneath the form that caused it. Firefly also
  repeats one sentence across every field it might apply to, so a single
  unresolved account arrived four times over in one line. Each distinct
  sentence is said once now. The empty foreign amount field also complained in
  the same words as an empty main amount, which read as though the amount
  already typed was the one refused

### Changed

- The name is spelled FireRaccoon. It had shipped as FireRacoon in the package
  names, file paths, bundle identifiers, environment variables, stored
  preference keys and the OAuth callback scheme. Nothing keeps working under the
  old spelling, so upgrading is not a drop-in
- Bundle identifiers are `com.fireraccoon` and `com.fireraccoon.app`. macOS, iOS
  and Android read that as a different application, so an existing install will
  not upgrade in place and the secure storage written under the old identifier
  is not visible to the new one
- The OAuth redirect is `fireraccoon://oauth-callback`. Update the redirect URI
  on the Firefly III OAuth client before signing in again, or the callback is
  refused
- Three Firefly III preference keys were renamed: the people config, the account
  classifications and the side menu layout. Values saved under the old keys are
  no longer read and those settings start from their defaults
- Settings backups exported by an earlier version carry the old app marker and
  are refused on import
- `FIRERACCOON_MODE`, `FIRERACCOON_URL`, `FIRERACCOON_API_KEY` and
  `FIRERACCOON_PORT` replace their old names, as do the `x-fireraccoon-session`
  header and the `fireraccoon_session` cookie. Compose files and MCP client
  configs need the new spelling, and open browser sessions are signed out once
- The published image is `ghcr.io/<owner>/fireraccoon`, a new package rather
  than a new tag on the old one

## [0.1.12] - 2026-08-25

### Added

- A Refresh button on the accounts view and on the dashboard. It had only ever
  been on the transactions screen, and the providers keep their data for the
  whole session, so an edit made in Firefly itself could not be picked up
  anywhere else short of relaunching. Pull-to-refresh does wrap every page, but
  it wants an overscroll from the top of a scrollable, which a trackpad makes
  close to undiscoverable

### Fixed

- A connection test that failed said only that it failed, which is the least
  useful thing to say while somebody is typing an address: a wrong URL, a
  rejected token and an unreachable host all look the same from outside. It
  names which of five it was. A refused insecure address is one of those
  reasons now rather than an exception thrown out of a button handler that does
  not catch it, so the one failure a person can fix on the spot no longer
  breaks the dialog
- A transfer between accounts in different currencies showed the amount that
  left the source where it should have shown the amount that arrived. Firefly
  states `amount` in the source account's currency and `foreign_amount` in the
  destination's, and every signing path read `amount` for both ends, so an
  account read from the receiving side reported the sending side's figure
  against its own symbol, wrong by whatever the rate happened to be
- Test fixtures carried account names, account ids, a journal id and amounts
  copied out of the ledger they were found in, one of them with a comment
  saying so. They use neutral values now, and the commits that introduced them
  were rewritten on `dev`, which leaves every tag and `main` untouched
- 0.1.11 gave the suites a seam to avoid production key-derivation cost, but it
  only reached code calling `hashPassword` directly. `PeopleNotifier` hashes
  inside itself, so every test that set a password still derived at 600k
  rounds, three times over in a test that adds a person, changes the password
  and logs back in. It read as flakiness, then timed a test out and blamed a
  disposed `Ref` the teardown had caused. The notifier takes the count now and
  the suite went from fourteen and a half minutes with a failure to eleven and
  a third green

### Removed

- The two HTML design prototypes. They had shipped a sample account list naming
  real banks since the first public release, and nothing in the build read them.
  `docs/design-spec.md` and `docs/architecture.md` say how to take them back out
  of the 0.1.2 tag, where the names do remain: purging those would mean
  rewriting every commit from the initial release forward and breaking every
  tag, to undo an exposure that is already public

## [0.1.11] - 2026-08-24

A security and data-safety release, from an audit of the secret store, the
server-mode API and the cryptography around passwords and backups.

### Fixed

- Disconnect deleted the server URL and the personal access token from the
  keychain the moment it was tapped. Nothing else holds a copy of the token, so
  one stray tap ended the connection for good. It asks first now, the same way
  every other irreversible action here asks
- Every secret lives in one keychain item, and a write rewrites the whole item,
  so two writes at once each started from their own copy and the later one
  discarded the other's key. Five concurrent writes left one key and lost four.
  A write also treated an item it could not read as an item holding nothing, so
  one unparseable byte took every secret with it. Mutations now share one copy,
  and a write that cannot read what it is replacing fails rather than guessing
- Nothing limited attempts at a sign-in or at the data password. Five failures
  inside fifteen minutes now earn a refusal, counted per caller and name
  together. A sign-in also answered faster for a name nobody had than for a real
  one, which told a caller which accounts exist
- Password hashing ran at a sixth of the iteration count OWASP gives for
  PBKDF2-HMAC-SHA256, and could not be raised: a stored hash did not record what
  produced it, so moving the constant would have turned every existing password
  into a wrong one. A hash carries its own count now, verification uses it, and
  the count is six times what it was. The derivation no longer runs on the
  isolate that draws the window
- The logger was given no secrets to redact, and could not have been given the
  API token, which exists only once the keychain answers. It is registered now as
  soon as there is one. The helper that encodes a payload for logging returned it
  unredacted
- The Firefly proxy forwarded any path it was handed with the installation's own
  token attached, so anyone who could sign in could reach any address on the
  Firefly host carrying it. It is restricted to the API, and Firefly's own
  cookies are no longer passed on
- The server-mode API answered every origin on the web with a wildcard. Origins
  are named in `CORS_ALLOWED_ORIGINS` now, and the default is none, which is
  what a server that hosts its own web UI needs
- Whoever reached a fresh install first became its admin and inherited the
  bootstrapped Firefly token. Setup asks for the data password, which the
  operator has and an unattended port does not
- A split transaction with some legs reconciled and some not could not be moved:
  not finished, not undone, and not even selected. It behaves like any other row
- A settings backup was unsealed at whatever the current iteration count was
  rather than the one recorded in the file, so raising that count would have made
  every existing backup unopenable and looked like a forgotten passphrase
- The encrypted store believed any iteration count in its own header, including
  zero or one, and derived a weak key from it rather than refusing
- A session arriving in a header or a cookie was returned unchecked while a
  bearer was resolved, so the same helper answered two different questions

### Changed

- `flutter_secure_storage` moves to 11. Data written by version 10 is unaffected
- Test suites no longer pay production key-derivation cost. The backend suite
  went from nine and a half minutes to ten seconds

## [0.1.10] - 2026-08-23

### Added

- A transfer can exchange its two accounts from a button between them. Entering
  one the wrong way round meant clearing both fields and retyping them through
  the autocomplete. Only a transfer offers it: exchanging the ends of a
  withdrawal would turn money spent into money earned

### Fixed

- A server URL aimed at a user interface host, or at a single sign-on front
  door, was reported as a working connection. The check looked only at the
  status code, and a login page answers 200, so a wrong address passed and every
  request after it failed on HTML with "FormatException: Unexpected character
  (at character 1)". The connection test now requires Firefly's own `about`
  payload, and a response that is a page is refused where it arrives, naming the
  address to check
- Reads that left one end of a date window open asked for dates Firefly refuses.
  It validates both ends against 32-bit time, the start after 1970-01-02 and the
  end before 2038-01-17, and the placeholders sat at 1900 and 2200 with the
  account panel reaching fifty years ahead. The refusal is not treated as an
  error on that path but as an empty page, so an account with a full history and
  months of write-ahead recurrences could read as one holding nothing
- A keychain that could not be read was reported as a server that had never been
  configured, so the app asked for credentials it already had and never looked
  at the keychain again until a relaunch. An unreadable read now says so, the
  read cannot hang forever, screens wait for it rather than erroring through it,
  and the connection poll reads again so unlocking recovers on its own

## [0.1.9] - 2026-08-23

### Added

- The accounts view reads a balance at any date you pick, refreshes on a button,
  and keeps the rows the ledger already holds for days that have not happened
  yet in their own collapsed block
- A forecast balance can be read for any day, not only the dates a projection
  marks
- The projection offers only open accounts, and accepts one typed in
- An account reports the account number and the IBAN. `find_account` matches on
  both and `update_account` writes them, so an identifier could be set and
  matched but never read back
- An empty string, or an empty list for `tags`, now removes a value over MCP.
  `notes`, category, budget, bill, piggy bank and tags could be set and never
  taken away: an update omits what it was not given, which made an empty value
  indistinguishable from an absent one

### Fixed

- A transaction reconciled in the app came back unreconciled on the next read.
  An unrelated edit dropped the flag it had not been asked to change
- An account shared with someone showed the share of its balance where it should
  have shown the balance. Only net worth and debt count a share
- `duplicate_transaction` produced a payload Firefly refused for every
  cross-currency transfer, because the foreign amount was never carried. A
  changed amount with no new rate is now refused rather than written wrong
- `match_statement` stopped reading at 1000 rows, reporting everything past the
  cap as missing. Its fetch is also padded at both ends by the near-date
  tolerance, so a row written a day either side of the statement still pairs
- A statement row converted into the account's currency never paired with the
  leg that recorded it
- An account's transactions endpoint answers a range carrying only one bound
  with nothing at all, so "everything before this date" came back empty rather
  than answering the question
- Two transaction lists wrote to themselves after disposal, which surfaced only
  as an unrelated test failing in a full run
- A transaction row narrower than about 390 logical pixels pushed its actions
  out of view, leaving nothing to edit it by. The amount moves to a second line
  instead, and the actions stay at every width
- An upcoming month could not be told apart from the month it repeats
- The keychain is asked once a launch rather than once a secret
- A release publishes the targets that built instead of none of them

### Changed

- The test gate allows three times the default per-test timeout. Password
  handling derives a key per call, 100k PBKDF2 rounds of pure Dart at close to
  two seconds each, and a test doing several of those under coverage
  instrumentation failed on machine load rather than on what it asserts

## [0.1.8] - 2026-08-21

### Added

- Bank statement import over MCP: `find_account` resolves raw bank text to an
  account, matching on account number and IBAN before any name tier and
  returning ranked candidates with the reason each matched. The identifier it
  matched on is never returned, only a last-four hint
- `match_statement` pairs statement rows against recorded split legs, reports
  near matches where a charge written ahead from an estimate drifted from the
  real one, and returns the arithmetic that proves each classification. Its
  tolerances are fixed constants, echoed in every response
- `get_capabilities` reports the person behind the presented key
- `get_recurrences` returns the lines each rule creates: amount, both accounts,
  category, budget, bill and tags. A ledger with one standing transfer per
  person previously offered nothing but identical titles
- `create_transaction` and `duplicate_transaction` accept `splits`, and
  `get_transaction` returns the legs of a group, so a loan payment or a card
  bill can be read and written back whole
- `find_incomplete_transactions`, and a Missing information filter in the
  transactions list, for rows lacking a description, category, budget, tags,
  payee, notes or piggy bank
- `export_firefly_data` and a Back up Firefly data action in Settings: a
  versioned JSON snapshot of every entity the API exposes, for taking before a
  bulk change
- Future transactions are grouped by month, each month carrying the balance
  expected once it closes
- The account balance in the transactions header reads any date, not just today
- Initial open-source release preparation: LICENSE, contributing docs, CI fixes
- Roboto Slab (Apache 2.0) replaces proprietary Rockwell for numeric typography

### Fixed

- An account line printed by a bank resolved to nothing when no ledger account
  carried an identifier. Passing the account number, the strongest signal
  `find_account` has, made the answer strictly worse than passing the label
  alone
- `duplicate_transaction` flattened a split group to its first leg, so copying a
  three-leg mortgage created one leg of the first leg's amount after reporting
  the transaction as the full sum
- A statement covering a single day could not be reconciled: the window
  converted to `start == end`, which Firefly refuses outright
- A recurring rule dated after the 10th of the month could not be edited. The
  update payload omitted the transaction type, so Firefly validated every
  update as a withdrawal
- Future transactions sorted the opposite way to every other group, reversing
  the list where that block began

### Changed

- `update_account` exposes the fields the engine always accepted: identifiers,
  notes, role, currency, liability terms, and balances. Giving a payee an account
  number is what makes the next import a lookup instead of a name guess
- Environment template renamed to `.env.example` (matches CI and docs)
- Test fixtures no longer carry real ledger account names, a household member's
  first name or a residential street name

## [1.0.0] - TBD

First public release. See [README](README.md) for feature overview.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

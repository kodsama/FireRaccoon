# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- MCP `find_account` resolves raw bank text to an account, matching on account
  number and IBAN before any name tier and returning ranked candidates with the
  reason each matched. The identifier it matched on is never returned, only a
  last-four hint
- MCP `match_statement` pairs statement rows against recorded split legs, reports
  near matches where a charge written ahead from an estimate drifted from the real
  one, and returns the arithmetic that proves each classification. Its tolerances
  are fixed constants, echoed in every response
- `get_capabilities` reports the person behind the presented key
- Initial open-source release preparation: LICENSE, contributing docs, CI fixes
- Roboto Slab (Apache 2.0) replaces proprietary Rockwell for numeric typography

### Changed

- `update_account` exposes the fields the engine always accepted: identifiers,
  notes, role, currency, liability terms, and balances. Giving a payee an account
  number is what makes the next import a lookup instead of a name guess
- Environment template renamed to `.env.example` (matches CI and docs)

## [1.0.0] - TBD

First public release. See [README](README.md) for feature overview.

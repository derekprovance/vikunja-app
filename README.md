# Vikunja App — Android Fork

[![CI](https://github.com/derekprovance/vikunja-app/actions/workflows/ci.yml/badge.svg)](https://github.com/derekprovance/vikunja-app/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/derekprovance/vikunja-app?include_prereleases)](https://github.com/derekprovance/vikunja-app/releases/latest)
[![License](https://img.shields.io/github/license/derekprovance/vikunja-app)](LICENSE)
[![Talk on Matrix](https://img.shields.io/matrix/vikunja%3Amatrix.org)](https://matrix.to/#/#vikunja:matrix.org)

> Fork of [go-vikunja/app](https://github.com/go-vikunja/app) with a focus on a refined Android experience.

Flutter client for [Vikunja](https://github.com/go-vikunja/vikunja) — the open-source, self-hostable task manager. Supports list, Kanban, Gantt, and table views with team collaboration and end-to-end encryption.

## Status

Alpha pre-release. Requires the Vikunja **unstable** build. Do not run against production backends.

## Install

| Platform | Download |
|---|---|
| Android (beta) | [Google Play](https://play.google.com/store/apps/details?id=io.vikunja.app) · [Direct](https://dl.vikunja.io/app/) |
| iOS | Community-supported; no official support provided |
| All releases | [GitHub Releases](https://github.com/derekprovance/vikunja-app/releases) |

## Develop

```bash
flutter pub get && flutter run
```

Build targets, architecture overview, and code generation steps are documented in [CLAUDE.md](CLAUDE.md).

## Translate

Contribute or add a language at [vikunja.io/docs/translations](https://vikunja.io/docs/translations/).

## License

See [LICENSE](LICENSE). Based on [go-vikunja/app](https://github.com/go-vikunja/app).

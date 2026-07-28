# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.0.2] - 2026-07-28

### Added

- Added a clean macOS release pipeline for Developer ID signing, DMG packaging, notarization, stapling,
  checksum generation, and GitHub Release asset upload.
- Added PtionsPlus-style local `.release.env` support and `NOTARY_PROFILE` notarization for local releases.

### Fixed

- Treat nonempty plain text as Markdown and score mixed plain-text/HTML clipboard representations so
  syntax-highlighted Markdown is converted in the correct direction.
- Convert one fresh, internally consistent clipboard snapshot and report read failures instead of
  overwriting newer clipboard content with a cached value.
- Always show both conversion directions when available so users can override an incorrect detection;
  keep `⌘⏎` assigned to the detected recommendation.
- Preserve code contents, safe language metadata, embedded backticks, literal Markdown punctuation,
  formatted table cells, escaped table delimiters, and ordered-list start values in both directions.
- Preserve remote Markdown images as safe image HTML, with an alt-only image fallback for unsupported URLs.
- Notarize and staple the app before packaging, validate both the DMG and mounted app with Gatekeeper,
  reject debug `get-task-allow` entitlements, and generate basename-only checksums after notarization.

## [1.0.1] - 2026-04-29

### Added

- Regression coverage for clipboard format detection, Markdown/HTML round trips, nested lists, and RTF conversion.

### Fixed

- Improved clipboard format detection for simple Markdown snippets such as bullet lists, numbered lists,
  inline code, and bold text.
- Added an RTF fallback so rich text copied from apps without HTML clipboard content can still be converted
  to Markdown.
- Preserved nested list structure when converting rich text or HTML to Markdown.
- Preserved whitespace inside code blocks during HTML to Markdown conversion.

## [1.0.0] - 2026-02-27

### Added

- Markdown → Loop conversion (HTML/RTF clipboard)
- Loop → Markdown conversion (HTML parsing)
- Auto-detection of clipboard content type
- Support for headings, bold, italic, strikethrough, lists, ordered lists, task lists, tables, code blocks, inline code, links, images, blockquotes, horizontal rules
- macOS native SwiftUI app
- Keyboard shortcut ⌘⏎ for conversion
- Unicode checkbox support for task lists (☑/☐)
- Multi-format clipboard output (HTML + RTF + plain text)

[Unreleased]: https://github.com/trsdn/md2loop/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/trsdn/md2loop/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/trsdn/md2loop/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/trsdn/md2loop/releases/tag/v1.0.0

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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

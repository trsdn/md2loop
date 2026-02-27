# Contributing to md2loop

Thanks for your interest in contributing! Here's how you can help.

## Reporting bugs

- Open a [GitHub Issue](https://github.com/trsdn/md2loop/issues/new)
- Include the Markdown or HTML input that caused the problem
- Describe the expected vs. actual behavior
- Mention your macOS version

## Suggesting features

- Open an issue with the **enhancement** label
- Describe the use case and why it would be useful

## Pull requests

1. **Fork** the repository
2. **Create a branch** from `main` (`git checkout -b my-feature`)
3. **Make your changes** — keep commits focused and descriptive
4. **Test** that the app builds and converts correctly
5. **Open a Pull Request** against `main`

A maintainer will review your PR. Please be patient — small, well-scoped PRs are easier to review and merge.

## Development setup

```bash
git clone https://github.com/<your-fork>/md2loop.git
cd md2loop
xcodegen generate
swift build
```

Open `md2loop.xcodeproj` in Xcode for a full IDE experience.

## Code style

- Follow standard Swift conventions
- Use meaningful names; keep functions short
- Run `swift build` before submitting to catch compiler errors

## Code of Conduct

Please be respectful and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

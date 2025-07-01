# AudioTee.js Development Guide

This guide covers setting up the development environment and workflow for AudioTee.js.

## Project Structure

```
audiotee-js/
├── package.json           # npm package configuration with node-pre-gyp
├── index.js              # Main entry point, uses node-pre-gyp to find binary
├── lib/
│   └── AudioTeeStream.js # Core streaming class
├── scripts/
│   └── build.js          # Build script that copies AudioTee binary
├── test/
│   └── test.js           # Interactive and automated tests
├── examples/
│   └── basic-usage.js    # Usage examples and demos
├── .github/workflows/
│   └── release.yml       # CI/CD for automated releases
└── README.md             # User documentation
```

## Initial Setup

### 1. Clone and Install Dependencies

```bash
git clone <your-audiotee-js-repo>
cd audiotee-js
npm install
```

### 2. Build AudioTee Binary

You'll need the AudioTee Swift project to build the binary:

```bash
# Option A: If AudioTee is in parent directory (current setup)
cd ../audiotee
swift build -c release
cd ../audiotee-js

# Option B: If AudioTee is elsewhere, set the path
export AUDIOTEE_BINARY_PATH=/path/to/audiotee/.build/release/audiotee
```

### 3. Build the Package

```bash
npm run build
```

This copies the AudioTee binary to `bin/audiotee` and makes it executable.

## Development Workflow

### Testing

```bash
# Interactive test - requires audio playback
npm test

# Quick automated test
npm test quick

# Run examples
node examples/basic-usage.js
node examples/basic-usage.js 2  # Save to file example
```

### Building for Different Architectures

```bash
# For Intel Macs (if you have access)
npm run build

# For Apple Silicon (if you have access)  
npm run build

# Clean build artifacts
npm run clean
```

### Testing the Package Locally

```bash
# Test the package as if installed from npm
npm pack
npm install -g audiotee-js-1.0.0.tgz

# Test in another directory
cd /tmp
node -e "const { AudioTeeStream } = require('audiotee-js'); console.log('✅ Works!')"
```

## Release Process

### 1. Prepare Release

1. Update version in `package.json`
2. Update `CHANGELOG.md` (if you add one)
3. Test thoroughly on both Intel and Apple Silicon if possible
4. Commit changes

### 2. Create GitHub Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

Then create a release on GitHub. This will trigger the automated build process.

### 3. Automated Release (via GitHub Actions)

The workflow will:
1. Build AudioTee binary for Intel and Apple Silicon
2. Package binaries using node-pre-gyp
3. Upload binaries to GitHub releases
4. Publish package to npm
5. Test the published package

### 4. Manual Release (if needed)

```bash
# Build and package
npm run build
npm run package

# Publish binary to GitHub releases
npm run publish-binary

# Publish to npm
npm publish
```

## Configuration

### Environment Variables

- `AUDIOTEE_BINARY_PATH` - Path to AudioTee binary for building
- `GITHUB_TOKEN` - For publishing binaries to GitHub releases
- `NODE_AUTH_TOKEN` - For publishing to npm

### node-pre-gyp Configuration

The binary distribution is configured in `package.json`:

```json
{
  "binary": {
    "module_name": "audiotee",
    "module_path": "./bin/",
    "remote_path": "v{version}/",
    "package_name": "audiotee-v{version}-{platform}-{arch}.tar.gz",
    "host": "https://github.com/your-org/audiotee-js/releases/download/"
  }
}
```

Update the `host` URL to match your repository.

## Troubleshooting

### Binary Not Found During Build

```bash
# Check if AudioTee is built
ls -la ../audiotee/.build/release/audiotee

# Or set custom path
export AUDIOTEE_BINARY_PATH=/path/to/your/audiotee/binary
npm run build
```

### Permission Issues

```bash
# Make sure binary is executable
chmod +x bin/audiotee

# Check binary works
./bin/audiotee --help
```

### node-pre-gyp Issues

```bash
# Clear cache
npm run clean
rm -rf node_modules
npm install

# Debug node-pre-gyp
DEBUG=node-pre-gyp npm run package
```

## Code Style

- Follow the patterns in `.cursorrules`
- Use functional programming where possible
- No semicolons (per project preference)
- Handle errors via EventEmitter, don't throw
- Use British English in documentation
- Comprehensive JSDoc for public APIs

## Testing Checklist

Before releasing:

- [ ] Basic audio capture works
- [ ] Both JSON and binary formats work
- [ ] Sample rate conversion works
- [ ] Process filtering works (if testable)
- [ ] Error handling works (invalid args, missing binary, etc.)
- [ ] Package installs and works on clean system
- [ ] Examples in README work
- [ ] CI/CD builds successfully

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Update documentation
6. Submit a pull request

## Publishing Checklist

- [ ] Version updated in package.json
- [ ] Tests pass
- [ ] Documentation updated
- [ ] GitHub release created
- [ ] CI/CD completed successfully
- [ ] npm package published
- [ ] Installation test passes 
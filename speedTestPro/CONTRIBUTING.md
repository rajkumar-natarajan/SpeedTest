# Contributing to SpeedTest Pro

We welcome contributions to SpeedTest Pro! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature or bug fix
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## Development Setup

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ SDK
- macOS Monterey 12.0+

### Building the Project
1. Open `SpeedTestPro.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (⌘+R)

## Code Style Guidelines

### Swift Style
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comprehensive documentation for public APIs
- Follow consistent indentation (4 spaces)

### SwiftUI Best Practices
- Use `@State` for local view state
- Use `@ObservedObject` or `@StateObject` for external data
- Extract complex views into separate components
- Use proper view modifiers order

### Architecture
- Follow MVVM pattern
- Keep ViewModels testable and platform-independent
- Use async/await for asynchronous operations
- Handle errors gracefully with user-friendly messages

## Testing

### Unit Tests
- Write unit tests for all business logic
- Test edge cases and error conditions
- Maintain > 80% code coverage
- Use descriptive test method names

### UI Tests
- Test critical user flows
- Verify accessibility features
- Test on multiple device sizes
- Include performance tests

## Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Write clean, documented code
   - Add tests for new functionality
   - Update README if needed

3. **Test Your Changes**
   - Run all unit tests
   - Run UI tests
   - Test on multiple devices/simulators
   - Verify no regressions

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

5. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create a pull request with:
   - Clear title and description
   - List of changes made
   - Screenshots for UI changes
   - Test results

## Areas for Contribution

### High Priority
- [ ] Additional test servers for better global coverage
- [ ] Enhanced accessibility features
- [ ] Performance optimizations
- [ ] Additional language translations

### Medium Priority
- [ ] Apple Watch companion app
- [ ] Widgets for quick speed tests
- [ ] Advanced statistics and analytics
- [ ] Custom test configurations

### Low Priority
- [ ] Theme customization options
- [ ] Export formats (JSON, XML)
- [ ] Scheduled speed tests
- [ ] Network diagnostic tools

## Bug Reports

When reporting bugs, please include:
- iOS version
- Device model
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots or logs if helpful

## Feature Requests

For new features:
- Explain the use case
- Describe the proposed solution
- Consider impact on existing functionality
- Provide mockups for UI changes

## Questions?

If you have questions about contributing:
- Open an issue with the "question" label
- Check existing issues and pull requests
- Review the README for setup instructions

Thank you for contributing to SpeedTest Pro! 🚀

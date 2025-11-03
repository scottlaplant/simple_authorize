# Contributing to SimpleAuthorize

Thank you for your interest in contributing to SimpleAuthorize! We welcome contributions from everyone.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to simpleauthorize@gmail.com.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include as many details as possible:

* **Use a clear and descriptive title**
* **Describe the exact steps to reproduce the problem**
* **Provide specific examples** to demonstrate the steps
* **Describe the behavior you observed** and what you expected
* **Include Ruby version, Rails version, and gem version**
* **Include any error messages or stack traces**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

* **Use a clear and descriptive title**
* **Provide a step-by-step description** of the suggested enhancement
* **Explain why this enhancement would be useful**
* **List any alternative solutions** you've considered

### Pull Requests

* Fill in the pull request template
* Follow the Ruby style guide (RuboCop will check this)
* Include tests for new features or bug fixes
* Update documentation as needed
* Ensure all tests pass (`bundle exec rake test` and `bundle exec rspec`)
* Ensure RuboCop passes (`bundle exec rubocop`)

## Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/simple_authorize.git
   cd simple_authorize
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Set up git hooks with Overcommit**
   ```bash
   # Install git hooks
   bundle exec overcommit --install

   # (Optional) Install TruffleHog for secret scanning
   # macOS: brew install truffleHog
   # Linux: pip install truffleHog
   ```

   This sets up automatic checks before commits and pushes:
   * **Pre-commit**: RuboCop, trailing whitespace, YAML syntax
   * **Pre-push**: RuboCop, Minitest, RSpec, TruffleHog (if installed)
   * **Post-checkout**: Automatic bundle install

   To skip hooks temporarily (not recommended):
   ```bash
   git push --no-verify
   ```

4. **Run tests**
   ```bash
   # Run Minitest suite
   bundle exec rake test

   # Run RSpec suite
   bundle exec rspec

   # Run RuboCop
   bundle exec rubocop

   # Run all checks
   bundle exec rake
   ```

5. **Create a feature branch**
   ```bash
   git checkout -b my-new-feature
   ```

## Testing

We maintain high test coverage (89%+) and use both Minitest and RSpec:

* **Minitest**: `test/` directory - for integration and controller tests
* **RSpec**: `spec/` directory - for unit tests and matchers

Please ensure your changes include appropriate tests:

```ruby
# Minitest example
test "authorize succeeds when policy allows" do
  result = controller.authorize(post, :show?)
  assert_equal post, result
end

# RSpec example
it "permits action when policy allows" do
  expect { policy.show? }.to permit_action
end
```

## Code Style

We follow the Ruby Style Guide and enforce it with RuboCop:

* Use 2 spaces for indentation
* Use double quotes for strings
* Keep lines under 120 characters
* Write descriptive method and variable names
* Add comments for complex logic

Run RuboCop with:
```bash
bundle exec rubocop
```

Auto-fix issues with:
```bash
bundle exec rubocop -a
```

## Documentation

* Update README.md if you add features
* Add YARD documentation to public methods
* Update CHANGELOG.md with your changes
* Keep comments up-to-date with code changes

## Commit Messages

* Use present tense ("Add feature" not "Added feature")
* Use imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit first line to 72 characters
* Reference issues and pull requests after the first line

Example:
```
Add policy caching for improved performance

Implements request-level memoization for policy instances
to reduce database queries and improve response times.

Fixes #123
```

## Release Process

Maintainers will handle releases:

1. Update version in `lib/simple_authorize/version.rb`
2. Update CHANGELOG.md with release notes
3. Commit changes
4. Run `bundle exec rake release`

## Questions?

Feel free to:
* Open an issue for questions
* Email us at simpleauthorize@gmail.com
* Check existing documentation in the README

## Recognition

Contributors will be:
* Listed in the CHANGELOG for their contributions
* Credited in release notes
* Added to a CONTRIBUTORS file (if created)

Thank you for contributing to SimpleAuthorize! 🎉

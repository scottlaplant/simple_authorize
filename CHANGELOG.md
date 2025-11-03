# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Policy generator (`rails g simple_authorize:policy ModelName`) with support for:
  - Namespaced models (e.g., `Admin::Post`)
  - RSpec or Minitest test generation
  - Automatic test scaffolding with CRUD and scope tests
- Initial release of SimpleAuthorize
- Policy-based authorization system
- Controller concern with authorization methods
- Base policy class with default deny-all policies
- Policy scope support for filtering collections
- Strong parameters integration via `permitted_attributes` and `policy_params`
- Automatic verification module (opt-in)
- Headless policy support for policies without models
- Namespace support for policies
- Role-based helper methods (`admin_user?`, `contributor_user?`, `viewer_user?`)
- Custom error handling with `NotAuthorizedError`
- Install generator (`rails generate simple_authorize:install`)
- Configuration system via initializer
- Comprehensive documentation and examples
- Test helper methods for easy testing
- Backwards compatibility aliases for Pundit-style usage

## [0.1.0] - 2025-11-01

### Added
- Initial gem structure
- Core authorization framework extracted from production Rails application
- MIT license
- README with comprehensive documentation
- Generator templates for installation

[Unreleased]: https://github.com/scottlaplant/simple_authorize/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/scottlaplant/simple_authorize/releases/tag/v0.1.0

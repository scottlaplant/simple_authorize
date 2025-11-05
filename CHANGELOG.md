# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2025-11-05

### Fixed
- RuboCop compliance for all new policy modules
- Method naming convention (`standard_permissions` instead of `standard_permissions?`)
- Simplified conditional logic in Approvable module
- Code style improvements across test files

## [1.1.0] - 2025-11-05

### Added

#### Policy Composition
- **Reusable Policy Modules** - Built-in modules for common authorization patterns
- **Ownable Module** - Ownership-based authorization helpers
- **Publishable Module** - Publishing workflow authorization
- **Timestamped Module** - Time-based access control
- **Approvable Module** - Approval workflow helpers
- **SoftDeletable Module** - Soft deletion authorization
- **Custom Module Support** - Easy creation of custom authorization modules

#### Context-Aware Policies
- **Request Context** - Pass additional context to policies (IP, time, location, etc.)
- **Controller Integration** - `authorization_context` method for building context
- **Context in Scopes** - Context available in Policy::Scope classes
- **Common Patterns** - Built-in support for geographic restrictions, time-based access, rate limiting

## [1.0.0] - 2025-11-03

### Added

#### Core Authorization
- **Policy Generator** - Rails generator for creating policy classes (`rails g simple_authorize:policy ModelName`)
- **Install Generator** - Setup wizard creating initializer and base policy (`rails g simple_authorize:install`)
- **Headless Policies** - Authorization for actions without a specific record
- **Batch Authorization** - Efficiently authorize multiple records with `authorize_all`, `authorized_records`, and `partition_records`

#### Performance & Caching
- **Policy Caching** - Request-level memoization to reduce database queries and improve performance
- **Configurable Cache** - Enable/disable policy caching via `config.enable_policy_cache`

#### Instrumentation & Monitoring
- **ActiveSupport::Notifications** - Comprehensive instrumentation for authorization events
- **Audit Logging** - Track authorization attempts, denials, and policy scope usage
- **Custom Event Subscribers** - Hook into `authorize.simple_authorize` and `policy_scope.simple_authorize` events

#### API Support
- **JSON/XML Error Responses** - Automatic API-friendly error responses with proper HTTP status codes
- **API Request Detection** - Intelligent detection of API requests (JSON/XML format and headers)
- **Configurable Error Details** - Control error detail level with `config.api_error_details`
- **Status Code Handling** - 401 Unauthorized vs 403 Forbidden based on authentication state

#### Attribute-Level Authorization
- **Visible Attributes** - Control which attributes users can view (`visible_attributes`, `visible_attributes_for_action`)
- **Editable Attributes** - Control which attributes users can modify (`editable_attributes`, `editable_attributes_for_action`)
- **Filter Helpers** - Automatically filter attribute hashes based on policy rules
- **Strong Parameters Integration** - `policy_params` method for seamless Rails strong parameters integration

#### Testing Support
- **RSpec Matchers** - `permit_action`, `forbid_action`, `permit_mass_assignment`, `forbid_mass_assignment`
- **RSpec Helpers** - `permit_editing`, `forbid_editing`, `permit_viewing`, `forbid_viewing`
- **Minitest Helpers** - `assert_permit_action`, `assert_forbid_action` for Minitest users
- **Policy Testing** - Comprehensive test helpers for both testing frameworks

#### Internationalization
- **I18n Support** - Configurable error messages with internationalization support
- **Custom Translations** - Per-policy and per-action error message translations
- **Configurable Scope** - Customize I18n scope with `config.i18n_scope`
- **Fallback Messages** - Graceful fallback to default messages when translations are missing

#### Security & Best Practices
- **Authorization Verification** - `verify_authorized` and `verify_policy_scoped` to catch missing authorization
- **Skip Authorization** - Explicit `skip_authorization` and `skip_policy_scope` methods
- **Auto-Verify Module** - Optional automatic verification with `include SimpleAuthorize::Controller::AutoVerify`
- **Safe Redirects** - Security-conscious redirect handling preventing open redirect vulnerabilities

#### Developer Experience
- **Comprehensive Documentation** - Extensive README with examples and best practices
- **Error Messages** - Clear, actionable error messages for common mistakes
- **Helper Methods** - View helpers automatically included (`policy`, `policy_scope`, `authorized_user`)
- **Role Helpers** - Convenient `admin_user?`, `contributor_user?`, `viewer_user?` methods

### Changed
- Improved error handling with detailed exception information
- Enhanced policy class resolution with namespace support
- Better cache key generation for policy instances

### Fixed
- Policy scope resolution for collection classes
- Safe referrer path handling for redirects
- API request detection edge cases

### Security
- Added protection against open redirect vulnerabilities in `safe_referrer_path`
- Implemented proper HTTP status codes (401 vs 403) for API errors
- Enhanced authorization verification to prevent bypass attempts

## [0.1.0] - Initial Development

### Added
- Basic policy-based authorization
- Core authorization methods (`authorize`, `policy`, `policy_scope`)
- Integration with Rails controllers
- Basic test helpers
- Initial documentation

---

## Upgrading

### From 0.1.0 to 1.0.0

**Breaking Changes:**
None - v1.0.0 is fully backward compatible with 0.1.0.

**New Features:**
All features listed above are opt-in and won't affect existing implementations.

**Recommended Updates:**
1. Run `rails g simple_authorize:install` to generate the configuration file
2. Enable policy caching for better performance: `config.enable_policy_cache = true`
3. Enable instrumentation for monitoring: `config.enable_instrumentation = true`
4. Add RSpec matchers to your spec_helper: `require 'simple_authorize/rspec'`

**Configuration:**
```ruby
# config/initializers/simple_authorize.rb
SimpleAuthorize.configure do |config|
  config.enable_policy_cache = true       # Enable request-level policy caching
  config.enable_instrumentation = true    # Enable ActiveSupport::Notifications
  config.api_error_details = false        # Exclude sensitive details in API errors
  config.i18n_enabled = true              # Enable I18n support
  config.i18n_scope = "simple_authorize"  # I18n translation scope
  config.default_error_message = "You are not authorized to perform this action."
end
```

## Support

- **Documentation**: [README.md](README.md)
- **Issues**: [GitHub Issues](https://github.com/scottlaplant/simple_authorize/issues)
- **Security**: [SECURITY.md](SECURITY.md)
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)

[1.0.0]: https://github.com/scottlaplant/simple_authorize/releases/tag/v1.0.0
[0.1.0]: https://github.com/scottlaplant/simple_authorize/releases/tag/v0.1.0

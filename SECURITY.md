# Security Policy

## Supported Versions

We release patches for security vulnerabilities. Currently supported versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take the security of SimpleAuthorize seriously. If you discover a security vulnerability, please report it privately.

### How to Report

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. Use GitHub's private vulnerability reporting feature (see "Security" tab in the repository)
3. Or email security reports to: scottlaplant@gmail.com

### What to Include

Please include the following information in your report:

- Type of vulnerability (e.g., authorization bypass, XSS, injection)
- Full paths of source files related to the vulnerability
- The location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### Response Timeline

- **Initial Response**: Within 48 hours of receiving your report
- **Status Update**: Within 5 business days with an initial assessment
- **Fix Timeline**: Critical vulnerabilities will be addressed within 30 days
- **Disclosure**: We will coordinate with you on the disclosure timeline

### Security Update Process

1. We will confirm the vulnerability and determine its severity
2. We will develop and test a fix
3. We will release a new version with the security patch
4. We will publish a security advisory with details after the fix is released
5. We will credit you for the discovery (unless you prefer to remain anonymous)

## Security Best Practices

When using SimpleAuthorize in your application:

1. **Always verify authorization**: Use `verify_authorized` in controllers to ensure authorization is checked
2. **Secure policy defaults**: The default Policy class denies all actions - only permit what's necessary
3. **Test your policies**: Write comprehensive tests for all authorization logic
4. **Keep updated**: Regularly update to the latest version to get security patches
5. **Review policies**: Periodically audit your policy classes for authorization holes

## Known Security Considerations

### Authorization Bypass Prevention

- Always call `authorize` before performing sensitive actions
- Use `skip_authorization` explicitly and only when intentional
- Be careful with `headless_policy` - ensure proper authorization for non-resource actions

### Scope Security

- Always use `policy_scope` to filter collections
- Don't rely solely on view-level hiding - enforce at the data layer
- Test scope filtering with different user roles

## Dependencies

SimpleAuthorize has minimal dependencies (only Rails/ActiveSupport). We monitor our dependencies for security vulnerabilities and update promptly.

## Questions?

If you have questions about this security policy or SimpleAuthorize's security practices, please email scottlaplant@gmail.com.

# frozen_string_literal: true

require_relative "lib/simple_authorize/version"

Gem::Specification.new do |spec|
  spec.name = "simple_authorize"
  spec.version = SimpleAuthorize::VERSION
  spec.authors = ["Scott"]
  spec.email = ["scottlaplant@users.noreply.github.com"]

  spec.summary = "Simple, powerful authorization for Rails without external dependencies"
  spec.description = "SimpleAuthorize is a lightweight authorization framework for Rails that provides " \
                     "policy-based access control, role management, and scope filtering without requiring " \
                     "external gems. Inspired by Pundit but completely standalone."
  spec.homepage = "https://github.com/scottlaplant/simple_authorize"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/scottlaplant/simple_authorize"
  spec.metadata["changelog_uri"] = "https://github.com/scottlaplant/simple_authorize/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/scottlaplant/simple_authorize/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "i18n", ">= 1.0"
  spec.add_dependency "railties", ">= 6.0"

  # Development dependencies
  spec.add_development_dependency "rails", ">= 6.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

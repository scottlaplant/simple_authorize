# frozen_string_literal: true

# Require all policy modules
require_relative "policy_modules/ownable"
require_relative "policy_modules/publishable"
require_relative "policy_modules/timestamped"
require_relative "policy_modules/approvable"
require_relative "policy_modules/soft_deletable"

module SimpleAuthorize
  # Collection of reusable policy modules for common authorization patterns
  #
  # These modules can be mixed into your policy classes to add common
  # authorization functionality without duplicating code.
  #
  # Example:
  #   class ArticlePolicy < SimpleAuthorize::Policy
  #     include SimpleAuthorize::PolicyModules::Ownable
  #     include SimpleAuthorize::PolicyModules::Publishable
  #
  #     def show?
  #       published? || owner_or_admin?
  #     end
  #   end
  module PolicyModules
  end
end

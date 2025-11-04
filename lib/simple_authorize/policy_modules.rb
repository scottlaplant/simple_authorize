# frozen_string_literal: true

require_relative "policy_modules/ownable"
require_relative "policy_modules/publishable"
require_relative "policy_modules/timestamped"
require_relative "policy_modules/approvable"
require_relative "policy_modules/commentable"

module SimpleAuthorize
  # Reusable policy modules for common authorization patterns.
  #
  # These modules can be included in your policy classes to add common
  # authorization behaviors without duplicating code.
  #
  # @example Using Ownable
  #   class PostPolicy < ApplicationPolicy
  #     include SimpleAuthorize::PolicyModules::Ownable
  #
  #     def update?
  #       owner_or_admin?  # Provided by Ownable
  #     end
  #   end
  #
  # @example Using multiple modules
  #   class ArticlePolicy < ApplicationPolicy
  #     include SimpleAuthorize::PolicyModules::Ownable
  #     include SimpleAuthorize::PolicyModules::Publishable
  #     include SimpleAuthorize::PolicyModules::Timestamped
  #
  #     def update?
  #       owner? && editable_period?  # Combines Ownable + Timestamped
  #     end
  #   end
  #
  # @see PolicyModules::Ownable
  # @see PolicyModules::Publishable
  # @see PolicyModules::Timestamped
  # @see PolicyModules::Approvable
  # @see PolicyModules::Commentable
  module PolicyModules
    # Module version for tracking
    VERSION = "1.0.0"
  end
end

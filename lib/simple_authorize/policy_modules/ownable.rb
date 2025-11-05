# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides ownership-based authorization methods
    #
    # Include this module in your policy to add owner-based permissions:
    #
    #   class PostPolicy < SimpleAuthorize::Policy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #
    #     def show?
    #       published? || owner_or_admin?
    #     end
    #   end
    #
    # This module assumes your record has a `user_id` field that matches
    # the user's ID. Override the `owner?` method if you need different logic.
    module Ownable
      protected

      # Check if the current user owns the record
      def owner?
        return false unless user && record

        if record.respond_to?(:user_id)
          record.user_id == user.id
        elsif record.respond_to?(:user)
          record.user == user
        elsif record.respond_to?(:owner_id)
          record.owner_id == user.id
        elsif record.respond_to?(:owner)
          record.owner == user
        else
          false
        end
      end

      # Check if the user is the owner or an admin
      def owner_or_admin?
        owner? || admin?
      end

      # Check if the user is the owner or a contributor
      def owner_or_contributor?
        owner? || contributor?
      end

      # Common pattern: owners and admins can modify
      def can_modify?
        owner_or_admin?
      end

      # Common pattern: anyone can view, but only owners/admins can modify
      def standard_permissions
        {
          show: true,
          create: logged_in?,
          update: owner_or_admin?,
          destroy: owner_or_admin?
        }
      end
    end
  end
end

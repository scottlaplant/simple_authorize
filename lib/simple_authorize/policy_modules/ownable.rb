# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides ownership-based authorization helpers.
    #
    # Include this module in policies where records have a `user_id` attribute
    # to get common ownership-based authorization methods.
    #
    # @example Basic usage
    #   class PostPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #
    #     def update?
    #       owner_or_admin?  # Method from Ownable
    #     end
    #   end
    #
    # @example With custom ownership field
    #   class ProjectPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #
    #     private
    #
    #     def ownership_field
    #       :creator_id  # Override default :user_id
    #     end
    #   end
    module Ownable
      # Check if the current user owns the record.
      #
      # By default, checks if `record.user_id == user.id`.
      # Override {#ownership_field} to use a different attribute.
      #
      # @return [Boolean] true if user owns the record
      #
      # @example
      #   def destroy?
      #     owner?  # Only owners can destroy
      #   end
      def owner?
        return false unless user
        return false unless record.respond_to?(ownership_field)

        record.public_send(ownership_field) == user.id
      end

      # Check if user is the owner OR an admin.
      #
      # @return [Boolean] true if user owns the record or is an admin
      #
      # @example
      #   def update?
      #     owner_or_admin?
      #   end
      def owner_or_admin?
        owner? || admin?
      end

      # Common CRUD permissions based on ownership.
      #
      # Users can update their own records, admins can update any record.
      #
      # @return [Boolean] true if authorized to update
      def update?
        owner_or_admin?
      end

      # Common CRUD permissions based on ownership.
      #
      # Users can destroy their own records, admins can destroy any record.
      #
      # @return [Boolean] true if authorized to destroy
      def destroy?
        owner_or_admin?
      end

      protected

      # The attribute name used for ownership checks.
      #
      # Override this method in your policy to use a different field.
      #
      # @return [Symbol] the ownership field name (default: :user_id)
      #
      # @example Custom ownership field
      #   def ownership_field
      #     :author_id
      #   end
      def ownership_field
        :user_id
      end
    end
  end
end

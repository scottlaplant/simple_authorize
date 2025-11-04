# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides comment management authorization.
    #
    # Include this module in policies for records that can have comments
    # (e.g., posts, articles, projects).
    #
    # @example Basic usage
    #   class PostPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #     include SimpleAuthorize::PolicyModules::Commentable
    #
    #     # Gets create_comment?, moderate_comments?, delete_comment? methods
    #   end
    module Commentable
      # Check if user can create a comment on the record.
      #
      # Logged-in users can comment on visible records.
      #
      # @return [Boolean] true if authorized to create comments
      #
      # @example
      #   if policy(@post).create_comment?
      #     # Show comment form
      #   end
      def create_comment?
        logged_in? && record_visible?
      end

      # Check if user can moderate comments on the record.
      #
      # Record owners, moderators, and admins can moderate.
      #
      # @return [Boolean] true if authorized to moderate comments
      def moderate_comments?
        owner? || moderator? || admin?
      end

      # Check if user can delete comments on the record.
      #
      # Admins and moderators can delete any comment.
      #
      # @return [Boolean] true if authorized to delete comments
      def delete_comment?
        admin? || moderator?
      end

      # Check if user can approve comments on the record.
      #
      # Uses same rules as {#moderate_comments?}.
      #
      # @return [Boolean] true if authorized to approve comments
      def approve_comment?
        moderate_comments?
      end

      protected

      # Check if the record is visible to the user.
      #
      # Override this method in the including policy to customize visibility logic.
      #
      # @return [Boolean] true if record is visible
      #
      # @example
      #   def record_visible?
      #     record.published? || owner? || admin?
      #   end
      def record_visible?
        true  # Override in including class
      end

      # Check if user has moderator role.
      #
      # @return [Boolean] true if user is a moderator
      def moderator?
        user&.moderator?
      end

      # Check if user owns the record.
      #
      # This method should be provided by including the Ownable module.
      #
      # @return [Boolean] true if user owns the record
      def owner?
        raise "Include Ownable module to use Commentable" unless defined?(super)
        super
      end
    end
  end
end

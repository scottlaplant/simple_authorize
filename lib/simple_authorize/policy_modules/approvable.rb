# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides approval workflow authorization.
    #
    # Include this module in policies for records that require approval
    # (e.g., comments, user-generated content, moderated submissions).
    #
    # @example Basic usage
    #   class CommentPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Approvable
    #
    #     # Gets approve?, reject?, show? methods
    #   end
    #
    # @note Expects records to respond to `status` or `approved?` methods
    module Approvable
      # Check if user can approve the record.
      #
      # Admins and moderators can approve content.
      #
      # @return [Boolean] true if authorized to approve
      #
      # @example
      #   authorize @comment, :approve?
      def approve?
        admin? || moderator?
      end

      # Check if user can reject the record.
      #
      # Uses same rules as {#approve?}.
      #
      # @return [Boolean] true if authorized to reject
      def reject?
        approve?
      end

      # Check if record is pending approval.
      #
      # @return [Boolean] true if record is pending
      def pending?
        if record.respond_to?(:status)
          record.status == "pending"
        elsif record.respond_to?(:approved?)
          !record.approved?
        else
          false
        end
      end

      # Check if record is approved.
      #
      # @return [Boolean] true if record is approved
      def approved?
        if record.respond_to?(:status)
          record.status == "approved"
        elsif record.respond_to?(:approved?)
          record.approved?
        else
          false
        end
      end

      # Check if user can view the record.
      #
      # Admins and moderators can see everything.
      # Others can only see approved content.
      #
      # @return [Boolean] true if authorized to view
      def show?
        return true if admin? || moderator?
        approved?
      end

      protected

      # Check if user has moderator role.
      #
      # Override this if your app uses different role names.
      #
      # @return [Boolean] true if user is a moderator
      def moderator?
        user&.moderator?
      end
    end
  end
end

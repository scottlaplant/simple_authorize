# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides soft deletion authorization methods
    #
    # Include this module for records that support soft deletion:
    #
    #   class CommentPolicy < SimpleAuthorize::Policy
    #     include SimpleAuthorize::PolicyModules::SoftDeletable
    #
    #     def destroy?
    #       soft_deletable? && (owner? || admin?)
    #     end
    #   end
    #
    # Assumes records have a deleted_at timestamp or similar field.
    module SoftDeletable
      protected

      # Check if the record is soft deleted
      def soft_deleted?
        return false unless record

        if record.respond_to?(:deleted?)
          record.deleted?
        elsif record.respond_to?(:deleted_at)
          record.deleted_at.present?
        elsif record.respond_to?(:trashed?)
          record.trashed?
        elsif record.respond_to?(:archived?)
          record.archived?
        else
          false
        end
      end

      # Check if the record is not soft deleted
      def not_deleted?
        !soft_deleted?
      end

      # Check if the record supports soft deletion
      def soft_deletable?
        record && (
          record.respond_to?(:deleted_at) ||
          record.respond_to?(:deleted?) ||
          record.respond_to?(:trash!) ||
          record.respond_to?(:archive!)
        )
      end

      # Check if user can restore soft deleted records
      def can_restore?
        soft_deleted? && (admin? || (owner? && within_restore_window?))
      end

      # Check if user can permanently delete
      def can_permanently_destroy?
        admin?
      end

      # Check if we're within the restore window (default 30 days)
      def within_restore_window?(days = 30)
        return true unless soft_deleted?
        return true unless record.respond_to?(:deleted_at)

        record.deleted_at > days.days.ago
      end

      # Check if user can view soft deleted records
      def can_view_deleted?
        admin? || (owner? && within_restore_window?)
      end

      # Standard destroy that respects soft delete
      def safe_destroy?
        if soft_deletable?
          # Soft delete if supported
          owner_or_admin?
        else
          # Hard delete requires admin
          admin?
        end
      end
    end
  end
end

# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides time-based authorization helpers.
    #
    # Include this module in policies where authorization depends on when
    # a record was created or updated.
    #
    # @example Limiting edits to recent records
    #   class CommentPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #     include SimpleAuthorize::PolicyModules::Timestamped
    #
    #     def update?
    #       owner? && editable_period?
    #     end
    #   end
    #
    # @example Custom time periods
    #   class PostPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Timestamped
    #
    #     private
    #
    #     def recent_period
    #       30.days
    #     end
    #
    #     def edit_window
    #       2.hours
    #     end
    #   end
    module Timestamped
      # Check if record was created recently.
      #
      # Default: within the last 7 days. Override {#recent_period} to customize.
      #
      # @return [Boolean] true if record is recent
      #
      # @example
      #   def highlight?
      #     recent?  # Highlight recent posts
      #   end
      def recent?
        return false unless record.respond_to?(:created_at)
        record.created_at > recent_period.ago
      end

      # Check if record is stale (not recent).
      #
      # @return [Boolean] true if record is not recent
      def stale?
        !recent?
      end

      # Check if record is within the editable time window.
      #
      # Default: within 1 hour of creation. Override {#edit_window} to customize.
      #
      # @return [Boolean] true if still within edit window
      #
      # @example
      #   def update?
      #     owner? && editable_period?  # Can only edit within time window
      #   end
      def editable_period?
        return false unless record.respond_to?(:created_at)
        record.created_at > edit_window.ago
      end

      # Check if record was updated recently.
      #
      # @return [Boolean] true if record was recently updated
      def recently_updated?
        return false unless record.respond_to?(:updated_at)
        record.updated_at > recent_period.ago
      end

      protected

      # The time period considered "recent".
      #
      # Override this method to customize what "recent" means for your policy.
      #
      # @return [ActiveSupport::Duration] the recent period (default: 7 days)
      #
      # @example
      #   def recent_period
      #     30.days
      #   end
      def recent_period
        7.days
      end

      # The time window during which editing is allowed.
      #
      # Override this method to customize the edit window for your policy.
      #
      # @return [ActiveSupport::Duration] the edit window (default: 1 hour)
      #
      # @example
      #   def edit_window
      #     15.minutes
      #   end
      def edit_window
        1.hour
      end
    end
  end
end

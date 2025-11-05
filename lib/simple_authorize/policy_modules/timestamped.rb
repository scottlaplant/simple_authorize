# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides time-based authorization methods
    #
    # Include this module for time-sensitive permissions:
    #
    #   class EventPolicy < SimpleAuthorize::Policy
    #     include SimpleAuthorize::PolicyModules::Timestamped
    #
    #     def update?
    #       not_expired? && (owner? || admin?)
    #     end
    #   end
    #
    # Works with records that have timestamp fields like expired_at,
    # starts_at, ends_at, valid_until, etc.
    module Timestamped
      protected

      # Check if the record has expired
      def expired?
        return false unless record

        if record.respond_to?(:expired_at)
          record.expired_at && record.expired_at < Time.current
        elsif record.respond_to?(:expires_at)
          record.expires_at && record.expires_at < Time.current
        elsif record.respond_to?(:valid_until)
          record.valid_until && record.valid_until < Time.current
        elsif record.respond_to?(:ends_at)
          record.ends_at && record.ends_at < Time.current
        else
          false
        end
      end

      # Check if the record is not expired
      def not_expired?
        !expired?
      end

      # Check if the record is active (started but not ended)
      def active?
        started? && !ended?
      end

      # Check if the record has started
      def started?
        return true unless record

        if record.respond_to?(:starts_at)
          record.starts_at.nil? || record.starts_at <= Time.current
        elsif record.respond_to?(:available_from)
          record.available_from.nil? || record.available_from <= Time.current
        elsif record.respond_to?(:valid_from)
          record.valid_from.nil? || record.valid_from <= Time.current
        else
          true
        end
      end

      # Check if the record has ended
      def ended?
        expired?
      end

      # Check if record is within a time window
      def within_time_window?
        started? && not_expired?
      end

      # Check if the record is locked (cannot be modified)
      def locked?
        return false unless record

        if record.respond_to?(:locked_at)
          record.locked_at && record.locked_at < Time.current
        elsif record.respond_to?(:locked?)
          record.locked?
        elsif record.respond_to?(:frozen_at)
          record.frozen_at && record.frozen_at < Time.current
        else
          false
        end
      end

      # Check if record can be modified (not locked or expired)
      def can_modify_time_based?
        !locked? && not_expired?
      end

      # Business hours check (useful with context)
      def within_business_hours?(time = Time.current)
        hour = time.hour
        weekday = time.wday

        # Monday-Friday, 9 AM - 5 PM
        weekday.between?(1, 5) && hour >= 9 && hour < 17
      end
    end
  end
end

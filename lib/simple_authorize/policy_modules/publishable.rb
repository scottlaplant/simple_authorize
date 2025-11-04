# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides publishing workflow authorization.
    #
    # Include this module in policies for records that have a publishing workflow
    # (e.g., posts, articles, pages with draft/published status).
    #
    # @example Basic usage
    #   class PostPolicy < ApplicationPolicy
    #     include SimpleAuthorize::PolicyModules::Ownable
    #     include SimpleAuthorize::PolicyModules::Publishable
    #
    #     # Gets publish?, unpublish?, schedule?, show? methods
    #   end
    #
    # @note This module expects the Ownable module to be included for `owner?` method.
    #       It also expects records to respond to `published?` method.
    module Publishable
      # Check if user can publish the record.
      #
      # Admins can publish anything. Contributors can publish their own content.
      #
      # @return [Boolean] true if authorized to publish
      #
      # @example
      #   authorize @post, :publish?
      def publish?
        return true if admin?
        contributor? && owner?
      end

      # Check if user can unpublish the record.
      #
      # Uses same rules as {#publish?}.
      #
      # @return [Boolean] true if authorized to unpublish
      def unpublish?
        publish?
      end

      # Check if user can schedule publication.
      #
      # Uses same rules as {#publish?}.
      #
      # @return [Boolean] true if authorized to schedule
      def schedule?
        publish?
      end

      # Check if user can view the record.
      #
      # Admins and owners can see everything.
      # Others can only see published content.
      #
      # @return [Boolean] true if authorized to view
      def show?
        return true if admin? || owner?
        published_record?
      end

      protected

      # Check if the record is published.
      #
      # @return [Boolean] true if record is published
      def published_record?
        record.respond_to?(:published?) && record.published?
      end

      # Check if user has contributor role.
      #
      # Override this if your app uses different role names.
      #
      # @return [Boolean] true if user is a contributor
      def contributor?
        user&.contributor?
      end

      # Check if user owns the record.
      #
      # This method should be provided by including the Ownable module.
      #
      # @return [Boolean] true if user owns the record
      # @raise [NoMethodError] if Ownable module is not included
      def owner?
        raise "Include Ownable module to use Publishable" unless defined?(super)
        super
      end
    end
  end
end

# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides publishing workflow authorization methods
    #
    # Include this module for content that has draft/published states:
    #
    #   class ArticlePolicy < SimpleAuthorize::Policy
    #     include SimpleAuthorize::PolicyModules::Publishable
    #
    #     def show?
    #       published? || can_preview?
    #     end
    #   end
    #
    # This module assumes your record responds to `published?` or has a
    # `published` boolean field, and optionally `published_at` timestamp.
    module Publishable
      protected

      # Check if the record is published
      def published?
        return false unless record

        if record.respond_to?(:published?)
          record.published?
        elsif record.respond_to?(:published)
          record.published == true
        elsif record.respond_to?(:status)
          record.status == "published"
        elsif record.respond_to?(:published_at)
          record.published_at && record.published_at <= Time.current
        else
          false
        end
      end

      # Check if the record is a draft
      def draft?
        !published?
      end

      # Check if user can publish content
      def can_publish?
        admin? || (contributor? && owner?)
      end

      # Check if user can unpublish content
      def can_unpublish?
        admin? || (owner? && contributor?)
      end

      # Check if user can preview unpublished content
      def can_preview?
        owner? || admin? || contributor?
      end

      # Check if user can schedule publication
      def can_schedule?
        return false unless record.respond_to?(:scheduled_at) || record.respond_to?(:publish_at)

        can_publish?
      end

      # Filter attributes based on published state
      def publishable_visible_attributes(base_attributes = [])
        if published? || can_preview?
          base_attributes
        else
          base_attributes - sensitive_draft_attributes
        end
      end

      # Attributes that should be hidden in draft state
      def sensitive_draft_attributes
        %i[internal_notes draft_notes review_comments]
      end
    end
  end
end

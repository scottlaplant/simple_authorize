# frozen_string_literal: true

module SimpleAuthorize
  module PolicyModules
    # Provides approval workflow authorization methods
    #
    # Include this module for content that requires approval:
    #
    #   class DocumentPolicy < SimpleAuthorize::Policy
    #     include SimpleAuthorize::PolicyModules::Approvable
    #
    #     def update?
    #       not_approved? && (owner? || admin?)
    #     end
    #   end
    #
    # Assumes records have approval-related fields like approved, approved_at,
    # approval_status, pending_approval, etc.
    module Approvable
      protected

      # Check if the record is approved
      def approved?
        return false unless record

        if record.respond_to?(:approved?)
          record.approved?
        elsif record.respond_to?(:approved)
          record.approved == true
        elsif record.respond_to?(:approval_status)
          record.approval_status == "approved"
        elsif record.respond_to?(:approved_at)
          record.approved_at.present?
        else
          false
        end
      end

      # Check if the record is pending approval
      def pending_approval?
        return false unless record

        if record.respond_to?(:pending_approval?)
          record.pending_approval?
        elsif record.respond_to?(:pending_approval)
          record.pending_approval == true
        elsif record.respond_to?(:approval_status)
          record.approval_status == "pending"
        elsif record.respond_to?(:submitted_for_approval_at)
          record.submitted_for_approval_at.present? && !approved? && !rejected?
        else
          false
        end
      end

      # Check if the record is rejected
      def rejected?
        return false unless record

        if record.respond_to?(:rejected?)
          record.rejected?
        elsif record.respond_to?(:rejected)
          record.rejected == true
        elsif record.respond_to?(:approval_status)
          record.approval_status == "rejected"
        elsif record.respond_to?(:rejected_at)
          record.rejected_at.present?
        else
          false
        end
      end

      # Check if the record is not approved
      def not_approved?
        !approved?
      end

      # Check if user can approve (cannot approve own content)
      def can_approve?
        return false unless logged_in?

        if admin?
          true
        elsif contributor?
          # Contributors can approve others' content but not their own
          !owner?
        else
          false
        end
      end

      # Check if user can reject
      def can_reject?
        can_approve?
      end

      # Check if user can submit for approval
      def can_submit_for_approval?
        owner? && not_approved? && !pending_approval?
      end

      # Check if user can withdraw from approval
      def can_withdraw_approval?
        owner? && pending_approval?
      end

      # Check if content can be edited (typically not after approval)
      def can_edit_with_approval?
        if approved?
          admin? # Only admins can edit approved content
        else
          owner? || admin? # Owner can edit rejected or unapproved content
        end
      end
    end
  end
end

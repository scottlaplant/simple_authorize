# frozen_string_literal: true

module SimpleAuthorize
  # RSpec matchers for SimpleAuthorize policies
  #
  # To use these matchers, add this to your spec/rails_helper.rb or spec/spec_helper.rb:
  #
  #   require "simple_authorize/rspec"
  #
  # @example
  #   RSpec.describe PostPolicy do
  #     subject { described_class.new(user, post) }
  #
  #     context "as an admin" do
  #       let(:user) { build(:admin) }
  #
  #       it { is_expected.to permit_action(:destroy) }
  #       it { is_expected.to forbid_action(:publish) }
  #       it { is_expected.to permit_viewing(:user_id) }
  #       it { is_expected.to permit_editing(:published) }
  #     end
  #   end
  module RSpecMatchers
    extend RSpec::Matchers::DSL

    # Matcher for checking if a policy permits an action
    #
    # @example
    #   it { is_expected.to permit_action(:show) }
    #   expect(policy).to permit_action(:update)
    matcher :permit_action do |action|
      match do |policy|
        action_method = action.to_s.end_with?("?") ? action.to_s : "#{action}?"
        policy.public_send(action_method)
      end

      failure_message do |policy|
        "expected #{policy.class} to permit action :#{action} but it was forbidden"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to forbid action :#{action} but it was permitted"
      end
    end

    # Matcher for checking if a policy forbids an action
    #
    # @example
    #   it { is_expected.to forbid_action(:destroy) }
    #   expect(policy).to forbid_action(:update)
    matcher :forbid_action do |action|
      match do |policy|
        action_method = action.to_s.end_with?("?") ? action.to_s : "#{action}?"
        !policy.public_send(action_method)
      end

      failure_message do |policy|
        "expected #{policy.class} to forbid action :#{action} but it was permitted"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to permit action :#{action} but it was forbidden"
      end
    end

    # Matcher for checking if a policy permits viewing an attribute
    #
    # @example
    #   it { is_expected.to permit_viewing(:title) }
    #   expect(policy).to permit_viewing(:email)
    matcher :permit_viewing do |attribute|
      match do |policy|
        policy.attribute_visible?(attribute)
      end

      failure_message do |policy|
        "expected #{policy.class} to permit viewing :#{attribute} but it was hidden"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to forbid viewing :#{attribute} but it was visible"
      end
    end

    # Matcher for checking if a policy forbids viewing an attribute
    #
    # @example
    #   it { is_expected.to forbid_viewing(:password) }
    #   expect(policy).to forbid_viewing(:user_id)
    matcher :forbid_viewing do |attribute|
      match do |policy|
        !policy.attribute_visible?(attribute)
      end

      failure_message do |policy|
        "expected #{policy.class} to forbid viewing :#{attribute} but it was visible"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to permit viewing :#{attribute} but it was hidden"
      end
    end

    # Matcher for checking if a policy permits editing an attribute
    #
    # @example
    #   it { is_expected.to permit_editing(:title) }
    #   expect(policy).to permit_editing(:body)
    matcher :permit_editing do |attribute|
      match do |policy|
        policy.attribute_editable?(attribute)
      end

      failure_message do |policy|
        "expected #{policy.class} to permit editing :#{attribute} but it was not editable"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to forbid editing :#{attribute} but it was editable"
      end
    end

    # Matcher for checking if a policy forbids editing an attribute
    #
    # @example
    #   it { is_expected.to forbid_editing(:id) }
    #   expect(policy).to forbid_editing(:published)
    matcher :forbid_editing do |attribute|
      match do |policy|
        !policy.attribute_editable?(attribute)
      end

      failure_message do |policy|
        "expected #{policy.class} to forbid editing :#{attribute} but it was editable"
      end

      failure_message_when_negated do |policy|
        "expected #{policy.class} to permit editing :#{attribute} but it was not editable"
      end
    end
  end
end

# Auto-include matchers if RSpec is loaded
if defined?(RSpec)
  RSpec.configure do |config|
    config.include SimpleAuthorize::RSpecMatchers
  end
end

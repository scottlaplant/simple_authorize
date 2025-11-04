# frozen_string_literal: true

require "rails/generators/named_base"

module SimpleAuthorize
  module Generators
    # Rails generator to create a policy class for a model
    class PolicyGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Creates a SimpleAuthorize policy class for a model"

      argument :name, type: :string, required: true, banner: "ModelName"

      class_option :spec, type: :boolean, default: false, desc: "Generate RSpec test file instead of Minitest"
      class_option :skip_test, type: :boolean, default: false, desc: "Skip generating test file"
      class_option :with_modules, type: :boolean, default: false, desc: "Include common policy modules (Ownable, Publishable, etc.)"

      def create_policy_file
        template "policy.rb.tt", File.join("app/policies", class_path, "#{file_name}_policy.rb")
      end

      def create_concern_modules
        return unless options[:with_modules]
        return if File.exist?("app/policies/concerns")

        empty_directory "app/policies/concerns"
        create_file "app/policies/concerns/.gitkeep"
      end

      def create_test_file
        return if options[:skip_test]

        if options[:spec]
          template "policy_spec.rb.tt", File.join("spec/policies", class_path, "#{file_name}_policy_spec.rb")
        else
          template "policy_test.rb.tt", File.join("test/policies", class_path, "#{file_name}_policy_test.rb")
        end
      end

      private

      def policy_class_name
        "#{class_name}Policy"
      end

      def model_class_name
        class_name
      end

      def model_instance_name
        file_name
      end

      def namespaced_policy_class
        if class_path.empty?
          policy_class_name
        else
          "#{class_path.map(&:camelize).join("::")}::#{policy_class_name}"
        end
      end

      def include_modules?
        options[:with_modules]
      end

      def policy_modules
        return [] unless include_modules?

        [
          "SimpleAuthorize::PolicyModules::Ownable",
          "SimpleAuthorize::PolicyModules::Publishable",
          "SimpleAuthorize::PolicyModules::Timestamped"
        ]
      end

      def module_comments
        return [] unless include_modules?

        [
          "# Ownable: Adds owner?, owner_or_admin? methods and ownership-based update?/destroy?",
          "# Publishable: Adds publish?, unpublish?, schedule? methods and published-aware show?",
          "# Timestamped: Adds recent?, stale?, editable_period? time-based authorization helpers"
        ]
      end
    end
  end
end

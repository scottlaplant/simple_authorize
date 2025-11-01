# frozen_string_literal: true

require "rails/generators"

module SimpleAuthorize
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a SimpleAuthorize initializer and ApplicationPolicy base class"

      def copy_initializer
        template "simple_authorize.rb", "config/initializers/simple_authorize.rb"
      end

      def copy_application_policy
        template "application_policy.rb", "app/policies/application_policy.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end

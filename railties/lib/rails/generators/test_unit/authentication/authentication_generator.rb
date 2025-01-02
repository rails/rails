# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class AuthenticationGenerator < Rails::Generators::Base # :nodoc:
      def create_user_test_files
        template "test/fixtures/users.yml"
        template "test/models/user_test.rb"
      end

      def create_controller_test_files
        template "test/controllers/sessions_controller_test.rb"
      end

      def configure_test_helpers
        template "test/test_helpers/session_test_helper.rb"
        inject_into_class "test/test_helper.rb", "TestCase", "    include SessionTestHelper\n"

        environment(nil, env: "test") do
          <<~RUBY
            # Load test helpers
            config.autoload_paths += %w[ test/test_helpers ]
          RUBY
        end
      end
    end
  end
end

# frozen_string_literal: true

require "active_support/test_case"
require "active_support/testing/autorun"
require "rails/generators/rails/app/app_generator"

module Rails
  module Generators
    class InteractiveOptionsTest < ActiveSupport::TestCase # :nodoc:
      def test_perform
        interactive_options = InteractiveOptions.new({ skip_action_text: false })

        def interactive_options.inquire_rails_version
          "edge"
        end

        def interactive_options.inquire_database
          "mysql"
        end

        def interactive_options.inquire_active_storage
          false
        end

        def interactive_options.inquire_action_cable
          true
        end

        def interactive_options.inquire_action_mailer
          true
        end

        def interactive_options.inquire_action_mailbox
          true
        end

        def interactive_options.inquire_action_text
          true
        end

        def interactive_options.inquire_bootsnap
          true
        end

        def interactive_options.inquire_jbuilder
          true
        end

        def interactive_options.inquire_javascript
          true
        end

        def interactive_options.inquire_spring
          true
        end

        def interactive_options.inquire_sprockets
          true
        end

        def interactive_options.inquire_system_tests
          true
        end

        def interactive_options.inquire_turbolinks
          true
        end

        def interactive_options.inquire_webpack
          false
        end

        def interactive_options.inquire_webpack_library
          "stimulus"
        end

        io = capture_io { interactive_options.perform }

        assert_match "Rails CLI #{Rails.version}\n", io.join
        assert_equal true,        interactive_options.options[:edge]
        assert_equal "mysql",     interactive_options.options[:database]
        assert_equal true,        interactive_options.options[:skip_action_cable]
        assert_equal true,        interactive_options.options[:skip_action_mailer]
        assert_equal true,        interactive_options.options[:skip_action_mailbox]
        assert_equal false,       interactive_options.options[:skip_active_storage]
        assert_equal true,        interactive_options.options[:skip_action_text]
        assert_equal true,        interactive_options.options[:skip_bootsnap]
        assert_equal true,        interactive_options.options[:skip_jbuilder]
        assert_equal true,        interactive_options.options[:skip_javascript]
        assert_equal true,        interactive_options.options[:skip_spring]
        assert_equal true,        interactive_options.options[:skip_sprockets]
        assert_equal true,        interactive_options.options[:skip_system_tests]
        assert_equal true,        interactive_options.options[:skip_turbolinks]
        assert_equal false,       interactive_options.options[:skip_webpack_install]
        assert_equal "stimulus",  interactive_options.options[:webpack]
      end
    end
  end
end

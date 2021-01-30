# frozen_string_literal: true

gem "capybara"
require "capybara"

module ActionDispatch
  module Assertions
    # Substitute <tt>rails-dom-testing</tt>-provided assertions with <tt>Capybara</tt>-powered assertions.
    #
    # By default, assertions about the contents of the response's body are provided by [rails-dom-testing][].
    #
    # Action Dispatch can also integrate with Capybara's selectors and assertions by including the <tt>ActionDispatch::Assertions::CapybaraAssertions</tt> module:
    #
    #
    #   require "test_helper"
    #   require "action_dispatch/testing/assertions/capybara"
    #
    #   class BlogFlowTest < ActionDispatch::IntegrationTest
    #     include ActionDispatch::Assertions::CapybaraAssertions
    #
    #     test "can see the welcome page" do
    #       get "/"
    #       assert_css "h1", "Welcome#index"
    #     end
    #   end
    #
    # In addition to the assertions provided by <tt>Capybara::Minitest::Assertions</tt>, <tt>ActionDispatch::Assertions::CapybaraAssertions</tt> also declares a <tt>within</tt> test helper to change the current scope and a <tt>page</tt> test helper to access the <tt>Capybara::Session</tt> directly.
    #
    # Mix the <tt>ActionDispatch::Assertions::CapybaraAssertions</tt> module into the <tt>ActionDispatch::IntegrationTest</tt> class to
    # integrate with Capybara's selectors and assertions throughout your integration test suite:
    #
    #   # test/test_helper.rb
    #
    #   require "action_dispatch/testing/assertions/capybara"
    #
    #   # …
    #
    #   class ActionDispatch::IntegrationTest
    #     include ActionDispatch::Assertions::CapybaraAssertions
    #   end
    #
    module CapybaraAssertions
      extend ActiveSupport::Concern

      module IntegrationSessionExtensions
        delegate :within, to: :page

        # :nodoc:
        def _mock_session
          @_mock_session ||= page.driver.browser.rack_mock_session
        end

        # Access the RackTest-driven <tt>Capybara::Session</tt> instance
        #
        # Assertions provided by the <tt>Capybara::Minitest::Assertions</tt>
        # will implicitly interact with the <tt>Capybara::Session</tt> instance
        # returned by this method.
        #
        #   # Asserts a button with the text "Submit" exists in the response
        #   body HTML content:
        #
        #   assert_button "Submit"
        def page
          @page ||= Capybara::Session.new(:rack_test, @app)
        end
      end

      included do
        include Capybara::Minitest::Assertions

        setup { integration_session.extend(IntegrationSessionExtensions) }
      end

      class_methods do
        def test(...)
          Capybara.using_wait_time(0) { super }
        end
      end
    end
  end
end

require "action_dispatch/testing/request_encoder"

module ActionDispatch
  # An integration test spans multiple controllers and actions,
  # tying them all together to ensure they work together as expected. It tests
  # more completely than either unit or functional tests do, exercising the
  # entire stack, from the dispatcher to the database.
  #
  # At its simplest, you simply extend <tt>IntegrationTestCase</tt> and write your tests
  # using the get/post methods:
  #
  #   require "test_helper"
  #
  #   class ExampleTest < ActionDispatch::IntegrationTestCase
  #     fixtures :people
  #
  #     def test_login
  #       # get the login page
  #       get "/login"
  #       assert_equal 200, status
  #
  #       # post the login and follow through to the home page
  #       post "/login", params: { username: people(:jamis).username,
  #         password: people(:jamis).password }
  #       follow_redirect!
  #       assert_equal 200, status
  #       assert_equal "/home", path
  #     end
  #   end
  #
  # However, you can also have multiple session instances open per test, and
  # even extend those instances with assertions and methods to create a very
  # powerful testing DSL that is specific for your application. You can even
  # reference any named routes you happen to have defined.
  #
  #   require "test_helper"
  #
  #   class AdvancedTest < ActionDispatch::IntegrationTestCase
  #     fixtures :people, :rooms
  #
  #     def test_login_and_speak
  #       jamis, david = login(:jamis), login(:david)
  #       room = rooms(:office)
  #
  #       jamis.enter(room)
  #       jamis.speak(room, "anybody home?")
  #
  #       david.enter(room)
  #       david.speak(room, "hello!")
  #     end
  #
  #     private
  #
  #       module CustomAssertions
  #         def enter(room)
  #           # reference a named route, for maximum internal consistency!
  #           get(room_url(id: room.id))
  #           assert(...)
  #           ...
  #         end
  #
  #         def speak(room, message)
  #           post "/say/#{room.id}", xhr: true, params: { message: message }
  #           assert(...)
  #           ...
  #         end
  #       end
  #
  #       def login(who)
  #         open_session do |sess|
  #           sess.extend(CustomAssertions)
  #           who = people(who)
  #           sess.post "/login", params: { username: who.username,
  #             password: who.password }
  #           assert(...)
  #         end
  #       end
  #   end
  #
  # Another longer example would be:
  #
  # A simple integration test that exercises multiple controllers:
  #
  #   require 'test_helper'
  #
  #   class UserFlowsTest < ActionDispatch::IntegrationTestCase
  #     test "login and browse site" do
  #       # login via https
  #       https!
  #       get "/login"
  #       assert_response :success
  #
  #       post "/login", params: { username: users(:david).username, password: users(:david).password }
  #       follow_redirect!
  #       assert_equal '/welcome', path
  #       assert_equal 'Welcome david!', flash[:notice]
  #
  #       https!(false)
  #       get "/articles/all"
  #       assert_response :success
  #       assert_select 'h1', 'Articles'
  #     end
  #   end
  #
  # As you can see the integration test involves multiple controllers and
  # exercises the entire stack from database to dispatcher. In addition you can
  # have multiple session instances open simultaneously in a test and extend
  # those instances with assertion methods to create a very powerful testing
  # DSL (domain-specific language) just for your application.
  #
  # Here's an example of multiple sessions and custom DSL in an integration test
  #
  #   require 'test_helper'
  #
  #   class UserFlowsTest < ActionDispatch::IntegrationTestCase
  #     test "login and browse site" do
  #       # User david logs in
  #       david = login(:david)
  #       # User guest logs in
  #       guest = login(:guest)
  #
  #       # Both are now available in different sessions
  #       assert_equal 'Welcome david!', david.flash[:notice]
  #       assert_equal 'Welcome guest!', guest.flash[:notice]
  #
  #       # User david can browse site
  #       david.browses_site
  #       # User guest can browse site as well
  #       guest.browses_site
  #
  #       # Continue with other assertions
  #     end
  #
  #     private
  #
  #       module CustomDsl
  #         def browses_site
  #           get "/products/all"
  #           assert_response :success
  #           assert_select 'h1', 'Products'
  #         end
  #       end
  #
  #       def login(user)
  #         open_session do |sess|
  #           sess.extend(CustomDsl)
  #           u = users(user)
  #           sess.https!
  #           sess.post "/login", params: { username: u.username, password: u.password }
  #           assert_equal '/welcome', sess.path
  #           sess.https!(false)
  #         end
  #       end
  #   end
  #
  # See the {request helpers documentation}[rdoc-ref:ActionDispatch::Integration::RequestHelpers] for help on how to
  # use +get+, etc.
  #
  # === Changing the request encoding
  #
  # You can also test your JSON API easily by setting what the request should
  # be encoded as:
  #
  #   require "test_helper"
  #
  #   class ApiTest < ActionDispatch::IntegrationTestCase
  #     test "creates articles" do
  #       assert_difference -> { Article.count } do
  #         post articles_path, params: { article: { title: "Ahoy!" } }, as: :json
  #       end
  #
  #       assert_response :success
  #       assert_equal({ id: Article.last.id, title: "Ahoy!" }, response.parsed_body)
  #     end
  #   end
  #
  # The +as+ option passes an "application/json" Accept header (thereby setting
  # the request format to JSON unless overridden), sets the content type to
  # "application/json" and encodes the parameters as JSON.
  #
  # Calling +parsed_body+ on the response parses the response body based on the
  # last response MIME type.
  #
  # Out of the box, only <tt>:json</tt> is supported. But for any custom MIME
  # types you've registered, you can add your own encoders with:
  #
  #   ActionDispatch::IntegrationTestCase.register_encoder :wibble,
  #     param_encoder: -> params { params.to_wibble },
  #     response_parser: -> body { body }
  #
  # Where +param_encoder+ defines how the params should be encoded and
  # +response_parser+ defines how the response body should be parsed through
  # +parsed_body+.
  #
  # Consult the Rails Testing Guide for more.
  class IntegrationTestCase < ActiveSupport::TestCase
    include TestProcess::FixtureFile

    module UrlOptions
      extend ActiveSupport::Concern
      def url_options
        integration_session.url_options
      end
    end

    module Behavior
      extend ActiveSupport::Concern

      include Integration::Runner
      include ActionController::TemplateAssertions

      included do
        include ActionDispatch::Routing::UrlFor
        include UrlOptions # don't let UrlFor override the url_options method
        ActiveSupport.run_load_hooks(:action_dispatch_integration_test, self)
        @@app = nil
      end

      module ClassMethods
        def app
          if defined?(@@app) && @@app
            @@app
          else
            ActionDispatch.test_app
          end
        end

        def app=(app)
          @@app = app
        end

        def register_encoder(*args)
          RequestEncoder.register_encoder(*args)
        end
      end

      def app
        super || self.class.app
      end

      def document_root_element
        html_document.root
      end
    end

    include Behavior
  end
end

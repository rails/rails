require 'stringio'
require 'uri'
require 'active_support/core_ext/kernel/singleton_class'
require 'active_support/core_ext/object/try'
require 'rack/test'

module ActionDispatch
  # An integration test spans multiple controllers and actions,
  # tying them all together to ensure they work together as expected. It tests
  # more completely than either unit or functional tests do, exercising the
  # entire stack, from the dispatcher to the database.
  #
  # At its simplest, you simply extend <tt>TestCase</tt> and write your tests
  # using the get/post methods:
  #
  #   require "test_helper"
  #
  #   class ExampleTest < ActionDispatch::TestCase
  #     fixtures :people
  #
  #     def test_login
  #       # get the login page
  #       get "/login"
  #       assert_equal 200, status
  #
  #       # post the login and follow through to the home page
  #       post "/login", :username => people(:jamis).username,
  #         :password => people(:jamis).password
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
  #   class AdvancedTest < ActionDispatch::TestCase
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
  #           get(room_url(:id => room.id))
  #           assert(...)
  #           ...
  #         end
  #
  #         def speak(room, message)
  #           xml_http_request "/say/#{room.id}", :message => message
  #           assert(...)
  #           ...
  #         end
  #       end
  #
  #       def login(who)
  #         open_session do |sess|
  #           sess.extend(CustomAssertions)
  #           who = people(who)
  #           sess.post "/login", :username => who.username,
  #             :password => who.password
  #           assert(...)
  #         end
  #       end
  #   end
  class TestCase < ActiveSupport::TestCase
    include Testing::Runner
    include ActionController::TemplateAssertions
    include ActionDispatch::Routing::UrlFor

    # Use AD::TestCase for acceptance tests
    register_spec_type(/(Request|Integration)( ?Test)?\z/i, self)

    @@app = nil

    def self.app
      if !@@app && !ActionDispatch.test_app
        ActiveSupport::Deprecation.warn "Rails application fallback is deprecated " \
          "and no longer works, please set ActionDispatch.test_app", caller
      end

      @@app || ActionDispatch.test_app
    end

    def self.app=(app)
      @@app = app
    end

    def app
      super || self.class.app
    end

    def url_options
      reset! unless integration_session
      integration_session.url_options
    end
  end
end

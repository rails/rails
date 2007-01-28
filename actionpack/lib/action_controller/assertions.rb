require 'test/unit'
require 'test/unit/assertions'

module ActionController #:nodoc:
  # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
  # can be used against. These collections are:
  #
  # * assigns: Instance variables assigned in the action that are available for the view.
  # * session: Objects being saved in the session.
  # * flash: The flash objects currently in the session.
  # * cookies: Cookies being sent to the user on this request.
  #
  # These collections can be used just like any other hash:
  #
  #   assert_not_nil assigns(:person) # makes sure that a @person instance variable was set
  #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
  #   assert flash.empty? # makes sure that there's nothing in the flash
  #
  # For historic reasons, the assigns hash uses string-based keys. So assigns[:person] won't work, but assigns["person"] will. To
  # appease our yearning for symbols, though, an alternative accessor has been deviced using a method call instead of index referencing.
  # So assigns(:person) will work just like assigns["person"], but again, assigns[:person] will not work.
  #
  # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
  #
  # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
  # action call which can then be asserted against.
  #
  # == Manipulating the request collections
  #
  # The collections described above link to the response, so you can test if what the actions were expected to do happened. But
  # sometimes you also want to manipulate these collections in the incoming request. This is really only relevant for sessions
  # and cookies, though. For sessions, you just do:
  #
  #   @request.session[:key] = "value"
  #
  # For cookies, you need to manually create the cookie, like this:
  #
  #   @request.cookies["key"] = CGI::Cookie.new("key", "value")
  #
  # == Testing named routes
  #
  # If you're using named routes, they can be easily tested using the original named routes methods straight in the test case.
  # Example:
  #
  #  assert_redirected_to page_url(:title => 'foo')
  module Assertions
    def self.included(klass)
      %w(response selector tag dom routing model).each do |kind|
        require "action_controller/assertions/#{kind}_assertions"
        klass.send :include, const_get("#{kind.camelize}Assertions")
      end
    end

    def clean_backtrace(&block)
      yield
    rescue Test::Unit::AssertionFailedError => error
      framework_path = Regexp.new(File.expand_path("#{File.dirname(__FILE__)}/assertions"))
      error.backtrace.reject! { |line| File.expand_path(line) =~ framework_path }
      raise
    end
  end
end

module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:
      include ActionController::Assertions
    end
  end
end

require 'action_dispatch/http/request'
require 'action_dispatch/middleware/exception_wrapper'

module ActionDispatch
  # This class is used by ShowException middleware to guarantee
  # a response is returned by the app. This class can take multiple
  # exception applications calling each in turn until one returns
  # successfully. If no apps return successfully, a FAILSAFE_RESPONSE
  # is delivered
  class ExceptionFailsafe
    FAILSAFE_RESPONSE = [500, { 'Content-Type' => 'text/plain' },
      ["500 Internal Server Error\n" <<
       "If you are the administrator of this website, then please read this web " <<
       "application's log file and/or the web server's log file to find out what " <<
       "went wrong."]]

    def initialize(*exception_apps)
      @exception_apps = exception_apps.flatten.compact.uniq
    end

    def call(env)
      try_exception_apps(env, @exception_apps.dup)
    end

    private

    # Takes an array of exception apps, pops one off the front
    # and attempts to render the exception. Continues until
    # all apps have errored, then returns the FAILSAFE_RESPONSE
    def try_exception_apps(env, exception_apps)
      return FAILSAFE_RESPONSE if exception_apps.blank?
      exception_app = exception_apps.shift
      return exception_app.call(env)
    rescue Exception => failsafe_error
      $stderr.puts "Error during failsafe response: #{failsafe_error}\n  #{failsafe_error.backtrace * "\n  "}"
      try_exception_apps(env, exception_apps)
    end
  end
end

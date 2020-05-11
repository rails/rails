# frozen_string_literal: true

require "active_support/all"
require "action_controller"
require "irb"

module Rails
  module ConsoleMethods
    # reference the global "app" instance, created on demand. To recreate the
    # instance, pass a non-false value as the parameter.
    def app(create = false)
      @app_integration_instance = nil if create
      @app_integration_instance ||= new_session do |sess|
        sess.host! "www.example.com"
      end
    end

    # create a new session. If a block is given, the new session will be yielded
    # to the block before being returned.
    def new_session
      app = Rails.application
      session = ActionDispatch::Integration::Session.new(app)
      yield session if block_given?

      # This makes app.url_for and app.foo_path available in the console
      session.extend(app.routes.url_helpers)
      session.extend(app.routes.mounted_helpers)

      session
    end

    # reloads the environment
    def reload!(print = true)
      puts "Reloading..." if print
      Rails.application.reloader.reload!
      true
    end

    # reboot a brand new session and exit current context
    def reboot!(print = true)
      puts "Rebooting..." if print
      existing_context = IRB.CurrentContext
      Rails.application.reloader.reload!
      IRB.start
      existing_context.exit
      true
    end
  end
end

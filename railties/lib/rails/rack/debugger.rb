module Rails
  module Rack
    class Debugger
      def initialize(app)
        @app = app

        ARGV.clear # clear ARGV so that rails server options aren't passed to IRB

        require 'debugger'

        ::Debugger.start
        ::Debugger.settings[:autoeval] = true if ::Debugger.respond_to?(:settings)
        puts "=> Debugger enabled"
      rescue LoadError
        puts "You're missing the 'debugger' gem. Add it to your Gemfile, bundle, and try again."
        exit
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end

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
        puts "You need to install debugger to run the server in debugging mode. With gems, use 'gem install debugger'"
        exit
      end

      def call(env)
        @app.call(env)
      end
    end
  end
end

module Rack
  # Rack::Lock was commited to Rack core
  # http://github.com/rack/rack/commit/7409b0c
  # Remove this when Rack 1.0 is released
  unless defined? Lock
    class Lock
      FLAG = 'rack.multithread'.freeze

      def initialize(app, lock = Mutex.new)
        @app, @lock = app, lock
      end

      def call(env)
        old, env[FLAG] = env[FLAG], false
        @lock.synchronize { @app.call(env) }
      ensure
        env[FLAG] = old
      end
    end
  end
end

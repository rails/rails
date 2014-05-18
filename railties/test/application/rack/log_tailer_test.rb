require "isolation/abstract_unit"
require "rails/rack/log_tailer"
require "logger"
require "tempfile"

module ApplicationTests
  module RackTests
    class LogTailerTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      # middleware that logs stuff when the request closes
      class SomeMiddleware
        def initialize(app, logger)
          @app = app
          @logger = logger
        end

        def call(env)
          status, headers, body = @app.call(env)
          [status, headers, ::Rack::BodyProxy.new(body) { @logger.info "things happened!" }]
        end
      end

      test "tails logging that happens when the body is closed" do
        logfile = Tempfile.new('log_tailer_test').tap { |f| f.sync = true }
        logger = Logger.new(logfile)
        stdout = capture(:stdout) do
          app = Rails::Rack::LogTailer.new(SomeMiddleware.new(proc { |env| [200, {}, []] }, logger), logfile.path)
          response = app.call({})
          response.last.close
        end
        assert_match 'things happened!', stdout
      end
    end
  end
end

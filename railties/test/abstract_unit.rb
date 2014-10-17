ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../../load_paths", __FILE__)

require 'stringio'
require 'active_support/testing/autorun'
require 'fileutils'

require 'active_support'
require 'action_controller'
require 'action_view'
require 'rails/all'

module TestApp
  class Application < Rails::Application
    config.root = File.dirname(__FILE__)
    secrets.secret_key_base = 'b3c631c314c0bbca50c1b2843150fe33'
  end
end

# Skips the current run on Rubinius using Minitest::Assertions#skip
def rubinius_skip(message = '')
  skip message if RUBY_ENGINE == 'rbx'
end
# Skips the current run on JRuby using Minitest::Assertions#skip
def jruby_skip(message = '')
  skip message if defined?(JRUBY_VERSION)
end

class ActiveSupport::TestCase
  # FIXME: we have tests that depend on run order, we should fix that and
  # remove this method call.
  self.test_order = :sorted

  private

  def capture(stream)
    stream = stream.to_s
    captured_stream = Tempfile.new(stream)
    stream_io = eval("$#{stream}")
    origin_stream = stream_io.dup
    stream_io.reopen(captured_stream)

    yield

    stream_io.rewind
    return captured_stream.read
  ensure
    captured_stream.close
    captured_stream.unlink
    stream_io.reopen(origin_stream)
  end
end

require 'abstract_unit'
require 'active_support/ruby/shim'
require 'initializer'

RAILS_ROOT.replace File.join(File.dirname(__FILE__), "root")

module Rails
  class << self
    attr_accessor :vendor_rails
    def vendor_rails?() @vendor_rails end
  end
end

class ActiveSupport::TestCase
  def assert_stderr(match)
    $stderr = StringIO.new
    yield
    $stderr.rewind
    err = $stderr.read
    assert_match match, err
  ensure
    $stderr = STDERR
  end
end
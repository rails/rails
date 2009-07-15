# This is a test helper file that simulates a rails application being
# boot from scratch in vendored mode. This file should really only be
# required in test cases that use the isolation helper so that requires
# can be reset correctly.
RAILS_ROOT = File.join(File.dirname(__FILE__), "root")
RAILS_FRAMEWORK_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))

require "test/unit"
# We are purposely avoiding adding things to the load path to catch bugs that only happen in the genuine article
require File.join(RAILS_FRAMEWORK_ROOT, 'activesupport', 'lib', 'active_support', 'testing', 'isolation')
require File.join(RAILS_FRAMEWORK_ROOT, 'activesupport', 'lib', 'active_support', 'testing', 'declarative')

class Test::Unit::TestCase
  extend ActiveSupport::Testing::Declarative

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

# Fake boot.rb
module Rails
  class << self
    attr_accessor :vendor_rails

    def vendor_rails?
      @vendor_rails
    end

    def boot!
      # Require the initializer
      require File.join(RAILS_FRAMEWORK_ROOT, 'railties', 'lib', 'initializer')
      # Run the initializer the same way boot.rb does it
      Rails::Initializer.run(:install_gem_spec_stubs)
      Rails::GemDependency.add_frozen_gem_path
      Rails::Initializer.run(:set_load_path)
    end
  end
end

# All that for this:
Rails.boot!
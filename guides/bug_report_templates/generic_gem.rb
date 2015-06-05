require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  # Activate the gem you are reporting the issue against.
  gem 'activesupport', '4.2.0'
end

require 'active_support/core_ext/object/blank'
require 'minitest/autorun'

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class BugTest < Minitest::Test
  def test_stuff
    assert "zomg".present?
    refute "".present?
  end
end

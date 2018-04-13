# frozen_string_literal: true
begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  #gem "activerecord", "5.1.6"
  gem "activerecord", "5.2.0"
  gem "sqlite3"
end

require "active_record"
require "active_support"
require "minitest/autorun"
require "logger"

ActiveSupport::Deprecation.behavior = :raise

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :ducks, force: true do |t|
    t.text :appearance
  end
end

class Duck < ActiveRecord::Base
  store :appearance, accessors: [:color], coder: JSON

  after_create :set_attribute_value
  def set_attribute_value
    update_attributes(color: "red")
  end
end

class BugTest < Minitest::Test
  def test_store_accessor_after_create
    duck = Duck.create
    assert_equal "red", duck.color
  end
end

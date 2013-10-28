require File.expand_path('../../../../load_paths', __FILE__)

require 'config'

require 'active_support/testing/autorun'
require 'stringio'

require 'active_record'
require 'cases/test_case'
require 'active_support/dependencies'
require 'active_support/logger'

require 'support/config'
require 'support/connection'

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Connect to the database
ARTest.connect

# Quote "type" if it's a reserved word for the current connection.
QUOTED_TYPE = ActiveRecord::Base.connection.quote_column_name('type')

def current_adapter?(*types)
  types.any? do |type|
    ActiveRecord::ConnectionAdapters.const_defined?(type) &&
      ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters.const_get(type))
  end
end

def in_memory_db?
  current_adapter?(:SQLite3Adapter) &&
  ActiveRecord::Base.connection_pool.spec.config[:database] == ":memory:"
end

def supports_savepoints?
  ActiveRecord::Base.connection.supports_savepoints?
end

def with_env_tz(new_tz = 'US/Eastern')
  old_tz, ENV['TZ'] = ENV['TZ'], new_tz
  yield
ensure
  old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
end

def with_active_record_default_timezone(zone)
  old_zone, ActiveRecord::Base.default_timezone = ActiveRecord::Base.default_timezone, zone
  yield
ensure
  ActiveRecord::Base.default_timezone = old_zone
end

unless ENV['FIXTURE_DEBUG']
  module ActiveRecord::TestFixtures::ClassMethods
    def try_to_load_dependency_with_silence(*args)
      old = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger.level = ActiveSupport::Logger::ERROR
      try_to_load_dependency_without_silence(*args)
      ActiveRecord::Base.logger.level = old
    end

    alias_method_chain :try_to_load_dependency, :silence
  end
end

require "cases/validations_repair_helper"
class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include ActiveRecord::ValidationsRepairHelper

  self.fixture_path = FIXTURES_ROOT
  self.use_instantiated_fixtures  = false
  self.use_transactional_fixtures = true

  def create_fixtures(*fixture_set_names, &block)
    ActiveRecord::FixtureSet.create_fixtures(ActiveSupport::TestCase.fixture_path, fixture_set_names, fixture_class_names, &block)
  end
end

def load_schema
  # silence verbose schema loading
  original_stdout = $stdout
  $stdout = StringIO.new

  adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
  adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

  load SCHEMA_ROOT + "/schema.rb"

  if File.exists?(adapter_specific_schema_file)
    load adapter_specific_schema_file
  end
ensure
  $stdout = original_stdout
end

load_schema

class << Time
  unless method_defined? :now_before_time_travel
    alias_method :now_before_time_travel, :now
  end

  def now
    (@now ||= nil) || now_before_time_travel
  end

  def travel_to(time, &block)
    @now = time
    block.call
  ensure
    @now = nil
  end
end

module LogIntercepter
  attr_accessor :logged, :intercepted
  def self.extended(base)
    base.logged = []
  end
  def log(sql, name, binds = [], &block)
    if @intercepted
      @logged << [sql, name, binds]
      yield
    else
      super(sql, name,binds, &block)
    end
  end
end

module InTimeZone
  private

  def in_time_zone(zone)
    old_zone  = Time.zone
    old_tz    = ActiveRecord::Base.time_zone_aware_attributes

    Time.zone = zone ? ActiveSupport::TimeZone[zone] : nil
    ActiveRecord::Base.time_zone_aware_attributes = !zone.nil?
    yield
  ensure
    Time.zone = old_zone
    ActiveRecord::Base.time_zone_aware_attributes = old_tz
  end
end

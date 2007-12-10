require 'test/unit'

# Optionally load RubyGems
begin
  require 'rubygems'
rescue LoadError
end

# Mock out what we need from AR::Base
module ActiveRecord
  class Base
    class << self
      attr_accessor :pluralize_table_names
    end
    self.pluralize_table_names = true
  end

  module ConnectionAdapters
    class Column
      attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale
      def initialize(name, default, sql_type=nil)
        @namename
        @default=default
        @type=@sql_type=sql_type
      end

      def human_name
        @name.humanize
      end
    end
  end
end

# Mock up necessities from ActionView
module ActionView
  module Helpers
    module ActionRecordHelper; end
    class InstanceTag; end
  end
end

# Set RAILS_ROOT appropriately fixture generation
tmp_dir="#{File.dirname(__FILE__)}/../fixtures/tmp"
if defined?(RAILS_ROOT)
  RAILS_ROOT.replace(tmp_dir)
else
  RAILS_ROOT=tmp_dir
end
Dir.mkdir(RAILS_ROOT) unless File.exist?(RAILS_ROOT)

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"
require 'rails_generator'
require "#{File.dirname(__FILE__)}/generator_test_helper"

class RailsModelGeneratorTest < Test::Unit::TestCase
  include GeneratorTestHelper

  def setup
    ActiveRecord::Base.pluralize_table_names = true
    Dir.mkdir("#{RAILS_ROOT}/app") unless File.exist?("#{RAILS_ROOT}/app")
    Dir.mkdir("#{RAILS_ROOT}/app/views") unless File.exist?("#{RAILS_ROOT}/app/views")
    Dir.mkdir("#{RAILS_ROOT}/app/views/layouts") unless File.exist?("#{RAILS_ROOT}/app/views/layouts")
    Dir.mkdir("#{RAILS_ROOT}/config") unless File.exist?("#{RAILS_ROOT}/config")
    Dir.mkdir("#{RAILS_ROOT}/db") unless File.exist?("#{RAILS_ROOT}/db")
    Dir.mkdir("#{RAILS_ROOT}/test") unless File.exist?("#{RAILS_ROOT}/test")
    Dir.mkdir("#{RAILS_ROOT}/test/fixtures") unless File.exist?("#{RAILS_ROOT}/test/fixtures")
    Dir.mkdir("#{RAILS_ROOT}/public") unless File.exist?("#{RAILS_ROOT}/public")
    Dir.mkdir("#{RAILS_ROOT}/public/stylesheets") unless File.exist?("#{RAILS_ROOT}/public/stylesheets")
    File.open("#{RAILS_ROOT}/config/routes.rb", 'w') do |f|
      f<<"ActionController::Routing::Routes.draw do |map|\n\nend\n"
    end
  end

    def teardown
    FileUtils.rm_rf "#{RAILS_ROOT}/app"
    FileUtils.rm_rf "#{RAILS_ROOT}/test"
    FileUtils.rm_rf "#{RAILS_ROOT}/config"
    FileUtils.rm_rf "#{RAILS_ROOT}/db"
    FileUtils.rm_rf "#{RAILS_ROOT}/public"
  end

  def test_model_generates_resources
    run_generator('model', %w(Product))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_migration :create_products
  end

  def test_model_skip_migration_skips_migration
    run_generator('model', %w(Product --skip-migration))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_skipped_migration :create_products
  end

  def test_model_with_attributes_generates_resources_with_attributes
    run_generator('model', %w(Product name:string supplier_id:integer created_at:timestamp))

    assert_generated_model_for :product
    assert_generated_fixtures_for :products
    assert_generated_migration :create_products do |t|
      assert_generated_column t, :name, :string
      assert_generated_column t, :supplier_id, :integer
      assert_generated_column t, :created_at, :timestamp
    end
  end
end

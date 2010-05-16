require 'test/unit'
require 'fileutils'

# Mock out what we need from AR::Base
module ActiveRecord
  class Base
    class << self
      attr_accessor :pluralize_table_names, :timestamped_migrations
    end
    self.pluralize_table_names = true
    self.timestamped_migrations = true
  end

  module ConnectionAdapters
    class Column
      attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale

      def initialize(name, default, sql_type = nil)
        @name = name
        @default = default
        @type = @sql_type = sql_type
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
tmp_dir = "#{File.dirname(__FILE__)}/../fixtures/tmp"

if defined? RAILS_ROOT
  RAILS_ROOT.replace tmp_dir
else
  RAILS_ROOT = tmp_dir
end
FileUtils.mkdir_p RAILS_ROOT

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../../lib"
require 'initializer'

# Mocks out the configuration
module Rails
  def self.configuration
    Rails::Configuration.new
  end
end

require 'rails_generator'

class GeneratorTestCase < Test::Unit::TestCase
  include FileUtils

  def setup
    ActiveRecord::Base.pluralize_table_names = true

    mkdir_p "#{RAILS_ROOT}/app/views/layouts"
    mkdir_p "#{RAILS_ROOT}/config"
    mkdir_p "#{RAILS_ROOT}/db"
    mkdir_p "#{RAILS_ROOT}/test/fixtures"
    mkdir_p "#{RAILS_ROOT}/public/stylesheets"

    File.open("#{RAILS_ROOT}/config/routes.rb", 'w') do |f|
      f << "ActionController::Routing::Routes.draw do |map|\n\nend"
    end
  end

  def teardown
    rm_rf "#{RAILS_ROOT}/app"
    rm_rf "#{RAILS_ROOT}/test"
    rm_rf "#{RAILS_ROOT}/config"
    rm_rf "#{RAILS_ROOT}/db"
    rm_rf "#{RAILS_ROOT}/public"
  end

  def test_truth
    # don't complain, test/unit
  end

  # Instantiates the Generator.
  def build_generator(name, params)
    Rails::Generator::Base.instance(name, params)
  end

  # Runs the +create+ command (like the command line does).
  def run_generator(name, params)
    silence_generator do
      build_generator(name, params).command(:create).invoke!
    end
  end

  # Silences the logger temporarily and returns the output as a String.
  def silence_generator
    logger_original = Rails::Generator::Base.logger
    myout = StringIO.new
    Rails::Generator::Base.logger = Rails::Generator::SimpleLogger.new(myout)
    yield if block_given?
    Rails::Generator::Base.logger = logger_original
    myout.string
  end

  # Asserts that the given controller was generated.
  # It takes a name or symbol without the <tt>_controller</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_controller_for(name, parent = "ApplicationController")
    assert_generated_class "app/controllers/#{name.to_s.underscore}_controller", parent do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given model was generated.
  # It takes a name or symbol and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_model_for(name, parent = "ActiveRecord::Base")
    assert_generated_class "app/models/#{name.to_s.underscore}", parent do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given helper was generated.
  # It takes a name or symbol without the <tt>_helper</tt> part.
  # The contents of the module source file is passed to a block.
  def assert_generated_helper_for(name)
    assert_generated_module "app/helpers/#{name.to_s.underscore}_helper" do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given functional test was generated.
  # It takes a name or symbol without the <tt>_controller_test</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_functional_test_for(name, parent = "ActionController::TestCase")
    assert_generated_class "test/functional/#{name.to_s.underscore}_controller_test",parent do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given helper test test was generated.
  # It takes a name or symbol without the <tt>_helper_test</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_helper_test_for(name, parent = "ActionView::TestCase")
    path = "test/unit/helpers/#{name.to_s.underscore}_helper_test"
    # Have to pass the path without the "test/" part so that class_name_from_path will return a correct result
    class_name = class_name_from_path(path.gsub(/^test\//, ''))

    assert_generated_class path,parent,class_name do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given unit test was generated.
  # It takes a name or symbol without the <tt>_test</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_unit_test_for(name, parent = "ActiveSupport::TestCase")
    assert_generated_class "test/unit/#{name.to_s.underscore}_test", parent do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given file was generated.
  # The contents of the file is passed to a block.
  def assert_generated_file(path)
    assert_file_exists(path)
    File.open("#{RAILS_ROOT}/#{path}") do |f|
      yield f.read if block_given?
    end
  end

  # asserts that the given file exists
  def assert_file_exists(path)
    assert File.exist?("#{RAILS_ROOT}/#{path}"),
      "The file '#{RAILS_ROOT}/#{path}' should exist"
  end

  # Asserts that the given class source file was generated.
  # It takes a path without the <tt>.rb</tt> part and an optional super class.
  # The contents of the class source file is passed to a block.
  def assert_generated_class(path, parent = nil, class_name = class_name_from_path(path))
    assert_generated_file("#{path}.rb") do |body|
      assert_match /class #{class_name}#{parent.nil? ? '':" < #{parent}"}/, body, "the file '#{path}.rb' should be a class"
      yield body if block_given?
    end
  end

  def class_name_from_path(path)
    # FIXME: Sucky way to detect namespaced classes
    if path.split('/').size > 3
      path =~ /\/?(\d+_)?(\w+)\/(\w+)$/
      "#{$2.camelize}::#{$3.camelize}"
    else
      path =~ /\/?(\d+_)?(\w+)$/
      $2.camelize
    end
  end

  # Asserts that the given module source file was generated.
  # It takes a path without the <tt>.rb</tt> part.
  # The contents of the class source file is passed to a block.
  def assert_generated_module(path)
    # FIXME: Sucky way to detect namespaced modules
    if path.split('/').size > 3
      path =~ /\/?(\w+)\/(\w+)$/
      module_name = "#{$1.camelize}::#{$2.camelize}"
    else
      path =~ /\/?(\w+)$/
      module_name = $1.camelize
    end

    assert_generated_file("#{path}.rb") do |body|
      assert_match /module #{module_name}/, body, "the file '#{path}.rb' should be a module"
      yield body if block_given?
    end
  end

  # Asserts that the given CSS stylesheet file was generated.
  # It takes a path without the <tt>.css</tt> part.
  # The contents of the stylesheet source file is passed to a block.
  def assert_generated_stylesheet(path)
    assert_generated_file("public/stylesheets/#{path}.css") do |body|
      yield body if block_given?
    end
  end

  # Asserts that the given YAML file was generated.
  # It takes a path without the <tt>.yml</tt> part.
  # The parsed YAML tree is passed to a block.
  def assert_generated_yaml(path)
    assert_generated_file("#{path}.yml") do |body|
      yaml = YAML.load(body)
      assert yaml, 'YAML data missing'
      yield yaml if block_given?
    end
  end

  # Asserts that the given fixtures YAML file was generated.
  # It takes a fixture name without the <tt>.yml</tt> part.
  # The parsed YAML tree is passed to a block.
  def assert_generated_fixtures_for(name)
    assert_generated_yaml "test/fixtures/#{name.to_s.underscore}" do |yaml|
      yield yaml if block_given?
    end
  end

  # Asserts that the given views were generated.
  # It takes a controller name and a list of views (including extensions).
  # The body of each view is passed to a block.
  def assert_generated_views_for(name, *actions)
    actions.each do |action|
      assert_generated_file("app/views/#{name.to_s.underscore}/#{action}") do |body|
        yield body if block_given?
      end
    end
  end

  def assert_generated_migration(name, parent = "ActiveRecord::Migration")
    file = Dir.glob("#{RAILS_ROOT}/db/migrate/*_#{name.to_s.underscore}.rb").first
    assert !file.nil?, "should have generated the migration file but didn't"

    file = file.match(/db\/migrate\/[0-9]+_\w+/).to_s
    assert_generated_class file, parent do |body|
      assert_match /timestamps/, body, "should have timestamps defined"
      yield body if block_given?
    end
  end

  # Asserts that the given migration file was not generated.
  # It takes the name of the migration as a parameter.
  def assert_skipped_migration(name)
    migration_file = "#{RAILS_ROOT}/db/migrate/001_#{name.to_s.underscore}.rb"
    assert !File.exist?(migration_file), "should not create migration #{migration_file}"
  end

  # Asserts that the given resource was added to the routes.
  def assert_added_route_for(name)
    assert_generated_file("config/routes.rb") do |body|
      assert_match /map.resources :#{name.to_s.underscore}/, body,
        "should add route for :#{name.to_s.underscore}"
    end
  end

  # Asserts that the given methods are defined in the body.
  # This does assume standard rails code conventions with regards to the source code.
  # The body of each individual method is passed to a block.
  def assert_has_method(body, *methods)
    methods.each do |name|
      assert body =~ /^  def #{name}(\(.+\))?\n((\n|   .*\n)*)  end/, "should have method #{name}"
      yield(name, $2) if block_given?
    end
  end

  # Asserts that the given column is defined in the migration.
  def assert_generated_column(body, name, type)
    assert_match /t\.#{type.to_s} :#{name.to_s}/, body, "should have column #{name.to_s} defined"
  end

  # Asserts that the given table is defined in the migration.
  def assert_generated_table(body, name)
    assert_match /create_table :#{name.to_s} do/, body, "should have table #{name.to_s} defined"
  end

  # Asserts the given field name gets translated to an attribute type
  # properly.
  #
  #   assert_attribute_type 'date', :date_select
  #
  def assert_attribute_type(name, attribute_type)
    assert_equal(
      Rails::Generator::GeneratedAttribute.new('test', name).field_type,
      attribute_type
    )
  end
end

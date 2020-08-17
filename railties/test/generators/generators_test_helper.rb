# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/module/remove_method"
require "active_support/testing/stream"
require "active_support/testing/method_call_assertions"
require "rails/generators"
require "rails/generators/test_case"

module Rails
  class << self
    remove_possible_method :root
    def root
      @root ||= Pathname.new(File.expand_path("../fixtures", __dir__))
    end
  end
end
Rails.application.config.root = Rails.root
Rails.application.config.generators.templates = [File.join(Rails.root, "lib", "templates")]

# Call configure to load the settings from
# Rails.application.config.generators to Rails::Generators
Rails.application.load_generators

require "active_record"
require "action_dispatch"
require "action_view"

module GeneratorsTestHelper
  include ActiveSupport::Testing::Stream
  include ActiveSupport::Testing::MethodCallAssertions

  GemfileEntry = Struct.new(:name, :version, :comment, :options, :commented_out) do
    def initialize(name, version, comment, options = {}, commented_out = false)
      super
    end
  end

  def self.included(base)
    base.class_eval do
      destination File.join(Rails.root, "tmp")
      setup :prepare_destination

      begin
        base.tests Rails::Generators.const_get(base.name.delete_suffix("Test"))
      rescue
      end
    end
  end

  def with_database_configuration(database_name = "secondary")
    original_configurations = ActiveRecord::Base.configurations
    ActiveRecord::Base.configurations = {
      test: {
        "#{database_name}": {
          database: "db/#{database_name}.sqlite3",
          migrations_paths: "db/#{database_name}_migrate",
        },
      },
    }
    yield
  ensure
    ActiveRecord::Base.configurations = original_configurations
  end

  def copy_routes
    routes = File.expand_path("../../lib/rails/generators/rails/app/templates/config/routes.rb.tt", __dir__)
    destination = File.join(destination_root, "config")
    FileUtils.mkdir_p(destination)
    FileUtils.cp routes, File.join(destination, "routes.rb")
  end

  def copy_gemfile(*gemfile_entries)
    locals = gemfile_locals.merge(gemfile_entries: gemfile_entries)
    gemfile = File.expand_path("../../lib/rails/generators/rails/app/templates/Gemfile.tt", __dir__)
    gemfile = evaluate_template(gemfile, locals)
    destination = File.join(destination_root)
    File.write File.join(destination, "Gemfile"), gemfile
  end

  def evaluate_template(file, locals = {})
    erb = if ERB.instance_method(:initialize).parameters.assoc(:key) # Ruby 2.6+
      ERB.new(File.read(file), trim_mode: "-", eoutvar: "@output_buffer")
    else
      ERB.new(File.read(file), nil, "-", "@output_buffer")
    end
    context = Class.new do
      locals.each do |local, value|
        class_attribute local, default: value
      end
    end
    erb.result(context.new.instance_eval("binding"))
  end

  private
    def gemfile_locals
      {
        skip_active_storage: true,
        depend_on_bootsnap: false,
        depend_on_listen: false,
        spring_install: false,
        depends_on_system_test: false,
        options: ActiveSupport::OrderedOptions.new,
      }
    end
end

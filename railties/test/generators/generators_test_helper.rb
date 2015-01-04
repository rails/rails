require 'abstract_unit'
require 'active_support/core_ext/module/remove_method'
require 'rails/generators'
require 'rails/generators/test_case'

module Rails
  class << self
    remove_possible_method :root
    def root
      @root ||= Pathname.new(File.expand_path('../../fixtures', __FILE__))
    end
  end
end
Rails.application.config.root = Rails.root
Rails.application.config.generators.templates = [File.join(Rails.root, "lib", "templates")]

# Call configure to load the settings from
# Rails.application.config.generators to Rails::Generators
Rails.application.load_generators

require 'active_record'
require 'action_dispatch'
require 'action_view'

module GeneratorsTestHelper
  def self.included(base)
    base.class_eval do
      destination File.join(Rails.root, "tmp")
      setup :prepare_destination

      begin
        base.tests Rails::Generators.const_get(base.name.sub(/Test$/, ''))
      rescue
      end
    end
  end

  def copy_routes
    routes = File.expand_path("../../../lib/rails/generators/rails/app/templates/config/routes.rb", __FILE__)
    destination = File.join(destination_root, "config")
    FileUtils.mkdir_p(destination)
    FileUtils.cp routes, destination
  end

  def quietly
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end

  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end
end

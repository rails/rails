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
      @root ||= Pathname.new(File.expand_path("../../fixtures", __FILE__))
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

  def self.included(base)
    base.class_eval do
      destination File.join(Rails.root, "tmp")
      setup :prepare_destination

      begin
        base.tests Rails::Generators.const_get(base.name.sub(/Test$/, ""))
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
end

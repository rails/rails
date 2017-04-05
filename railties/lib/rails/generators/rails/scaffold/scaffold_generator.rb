require "rails/generators/rails/resource/resource_generator"

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator # :nodoc:
      remove_hook_for :resource_controller
      remove_class_option :actions

      class_option :api, type: :boolean
      class_option :stylesheets, type: :boolean, desc: "Generate Stylesheets"
      class_option :stylesheet_engine, desc: "Engine for Stylesheets"
      class_option :assets, type: :boolean
      class_option :resource_route, type: :boolean
      class_option :scaffold_stylesheet, type: :boolean

      def handle_skip
        @options = @options.merge(stylesheets: false) unless options[:assets]
        @options = @options.merge(stylesheet_engine: false) unless options[:stylesheets] && options[:scaffold_stylesheet]
        @options = @options.merge(system_tests: false) if options[:api]
      end

      hook_for :scaffold_controller, required: true

      hook_for :system_tests, as: :system

      hook_for :assets do |assets|
        invoke assets, [controller_name]
      end

      hook_for :stylesheet_engine do |stylesheet_engine|
        if behavior == :invoke
          invoke stylesheet_engine, [controller_name]
        end
      end
    end
  end
end

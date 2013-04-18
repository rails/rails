require 'rails/generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator # :nodoc:
      remove_hook_for :resource_controller
      remove_class_option :actions

      class_option :helper, type: :boolean, default: true

      def handle_skip
        @options = @options.merge(stylesheets: false) unless options[:assets]
        @options = @options.merge(stylesheet_engine: false) unless options[:stylesheets]
      end

      hook_for :scaffold_controller, required: true

      hook_for :assets, type: :boolean, default: true do |assets|
        invoke assets, [controller_name]
      end
    end
  end
end

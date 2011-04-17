require 'rails/generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator #metagenerator
      remove_hook_for :resource_controller
      remove_class_option :actions

      class_option :stylesheets, :type => :boolean, :desc => "Generate stylesheets"
      class_option :stylesheet_engine, :desc => "Engine for stylesheets"

      hook_for :scaffold_controller, :required => true

      def copy_stylesheets_file
        if behavior == :invoke && options.stylesheets?
          template "scaffold.#{stylesheet_extension}", "app/assets/stylesheets/scaffold.#{stylesheet_extension}"
        end
      end

      hook_for :assets do |assets|
        invoke assets, [controller_name]
      end

      private

      def stylesheet_extension
        options.stylesheet_engine.present? ?
          "css.#{options.stylesheet_engine}" : "css"
      end
    end
  end
end

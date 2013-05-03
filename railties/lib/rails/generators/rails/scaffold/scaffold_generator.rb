require 'rails/generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator #metagenerator
      remove_hook_for :resource_controller
      remove_class_option :actions

      class_option :stylesheets, :type => :boolean, :desc => "Generate Stylesheets"
      class_option :stylesheet_engine, :desc => "Engine for Stylesheets"
      class_option :assets, :type => :boolean
      class_option :resource_route, :type => :boolean

      hook_for :scaffold_controller, :required => true

      hook_for :assets do |assets|
        invoke assets, [controller_name]
      end

      hook_for :stylesheet_engine do |stylesheet_engine|
        invoke stylesheet_engine, [controller_name] if options[:stylesheets] && behavior == :invoke
      end
    end
  end
end

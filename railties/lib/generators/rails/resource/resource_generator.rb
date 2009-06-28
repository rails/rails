require 'generators/rails/model/model_generator'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator
      hook_for :resource_controller

      class_option :actions, :type => :array, :default => [], :banner => "ACTION ACTION",
                             :desc => "Actions for the resource controller", :aliases => "-a"

      def invoke_for_resource_controller
        return unless options[:resource_controller]

        klass = Rails::Generators.find_by_namespace(options[:resource_controller], :rails, :controller)

        if klass
          args = []
          args << class_name.pluralize
          args.concat(options[:actions])

          say_status :invoke, options[:resource_controller], :blue
          klass.new(args, options.dup, _overrides_config).invoke(:all)
        else
          say "Could not find and invoke '#{options[:resource_controller]}'."
        end
      end

      # TODO Add singleton support
      def add_resource_routes
        route "map.resources :#{file_name.pluralize}"
      end

    end
  end
end

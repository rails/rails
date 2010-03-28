require 'rails/generators/resource_helpers'
require 'rails/generators/rails/model/model_generator'
require 'active_support/core_ext/object/blank'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator #metagenerator
      include ResourceHelpers

      hook_for :resource_controller, :required => true do |controller|
        invoke controller, [ controller_name, options[:actions] ]
      end

      class_option :actions, :type => :array, :banner => "ACTION ACTION", :default => [],
                             :desc => "Actions for the resource controller"

      class_option :singleton, :type => :boolean, :desc => "Supply to create a singleton controller"

      def add_resource_route
        return if options[:actions].present?
        route "resource#{:s unless options[:singleton]} :#{pluralize?(file_name)}"
      end

      protected

        def pluralize?(name)
          if options[:singleton]
            name
          else
            name.pluralize
          end
        end

    end
  end
end

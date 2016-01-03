require 'rails/generators/resource_helpers'
require 'rails/generators/rails/model/model_generator'

module Rails
  module Generators
    class ResourceGenerator < ModelGenerator # :nodoc:
      include ResourceHelpers

      hook_for :resource_controller, required: true do |controller|
        invoke controller, [ controller_name, options[:actions] ]
      end

      class_option :actions, type: :array, banner: "ACTION ACTION", default: [],
                             desc: "Actions for the resource controller"

      hook_for :resource_route, required: true
    end
  end
end

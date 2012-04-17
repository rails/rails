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

      class_option :http, :type => :boolean, :default => false,
                          :desc => "Generate resource with HTTP actions only"

      hook_for :resource_route, :required => true
    end
  end
end

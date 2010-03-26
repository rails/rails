require 'rails/generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator #metagenerator
      remove_hook_for :resource_controller
      remove_class_option :actions

      hook_for :scaffold_controller, :required => true
      hook_for :stylesheets
    end
  end
end

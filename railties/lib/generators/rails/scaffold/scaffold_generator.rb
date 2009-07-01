require 'generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator #metagenerator
      class_option :test_framework, :banner => "NAME", :desc => "Test framework to be invoked"

      remove_hook_for :actions, :resource_controller
      hook_for :scaffold_controller, :required => true
    end
  end
end

require 'generators/rails/resource/resource_generator'

module Rails
  module Generators
    class ScaffoldGenerator < ResourceGenerator
      remove_hook_for :actions, :resource_controller
    end
  end
end

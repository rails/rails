# frozen_string_literal: true

require_relative "../../model_helpers"

module Rails
  module Generators
    class ModelGenerator < NamedBase # :nodoc:
      include Rails::Generators::ModelHelpers

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"
      hook_for :orm, required: true, desc: "ORM to be invoked"

      def invoke_poro_model
        invoke(:poro_model, [name]) unless options.orm
      end
    end
  end
end

# frozen_string_literal: true

require "rails/generators/model_helpers"

module Rails
  module Generators
    class ModelGenerator < NamedBase # :nodoc:
      include Rails::Generators::ModelHelpers

      argument :attributes, type: :array, default: [], banner: "field[:type][:required][:index] field[:type][:required][:index]"
      hook_for :orm, required: true, desc: "ORM to be invoked"
    end
  end
end

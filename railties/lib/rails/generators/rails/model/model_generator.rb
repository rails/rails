//rails/generators/rails/model/model_generator.rb
//This generator creates a model file with the specified attributes and types. It also generates the corresponding migration file for the model. The generator can be used with different ORMs by specifying the desired ORM when running the generator. The generated model file will include the necessary code for the specified ORM, and the migration file will include the appropriate syntax for creating the database table with the specified attributes.
# frozen_string_literal: true

require "rails/generators/model_helpers"

module Rails
  module Generators
    class ModelGenerator < NamedBase # :nodoc:
      include Rails::Generators::ModelHelpers

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"
      hook_for :orm, required: true, desc: "ORM to be invoked"

      class << self
        delegate(:desc, to: :orm_generator)
      end
    end
  end
end

# frozen_string_literal: true

module Rails
  module Generators
    class MigrationGenerator < NamedBase # :nodoc:
      argument :attributes, type: :array, default: [], banner: "field[:type][:required][:index] field[:type][:required][:index]"
      hook_for :orm, required: true, desc: "ORM to be invoked"
    end
  end
end

# frozen_string_literal: true

require "active_record/errors"

module ActiveRecord
  module Conversion # :nodoc:
    # When an activerecord object is rendered in a form and displays validation errors per field
    # there is a mismatch between the validation error key for input fields and some associations
    # class Person
    #   belongs_to :team
    # end
    # Presence validation error for +team+ will live in +errors[:team]+ instead of +errors[:team_id]+
    # input field refers to +team_id+, therefore would not be div wrapped with class +field_with_errors+
    # When to_model is called, we setup up aliases for those fields
    def to_model
      unless errors.is_a?(ActiveRecord::Errors)
        @errors = ActiveRecord::Errors.new(self, errors.objects)

        self.class.reflect_on_all_associations.each do |reflection|
          case reflection.macro
          when :belongs_to
            @errors.alias(reflection.foreign_key, reflection.name)
          when :has_many, :has_and_belongs_to_many
            @errors.alias(reflection.ids_reader_name, reflection.name)
          end
        end
      end
      self
    end
  end
end

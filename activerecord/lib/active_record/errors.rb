# frozen_string_literal: true

require "active_model/errors"

module ActiveRecord
  # When an activerecord object is rendered in a form and displays validation errors per field
  # there is a mismatch between the validation error key for input fields
  # for +belongs_to+, +has_many+, +has_and_belongs_to_many associations+
  # E.g. <tt>class Person; belongs_to :team; end</tt>
  # Presence validation error for association +team+ will live in +errors[:team]+ instead of +errors[:team_id]+
  # Since input field refers to +team_id+, field is not div wrapped with class +field_with_errors+
  # This class supports setting aliases between attributes +{ team_id: team }+
  class Errors < ActiveModel::Errors
    def initialize(base, errors)
      @base = base
      @errors = errors
      @aliases = {}
    end

    def alias(to, from)
      @aliases[to.to_sym] = from.to_sym
    end

    # Overrides +where+ method from <tt>ActiveModel::Errors</tt> to also find errors from aliased attributes
    #   person.errors[:team]                     # => ["can't be blank"]
    #   person.errors[:team_id]                  # => []
    #   person.errors.alias(:team_id, :team)
    #   person.errors[:team_id]                  # => ["can't be blank"]
    def where(attribute, type = nil, **options)
      result = super
      if result.empty? && (aliased = @aliases[attribute.to_sym])
        super(aliased, type, **options)
      else
        result
      end
    end
  end
end

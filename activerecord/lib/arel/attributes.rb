# frozen_string_literal: true

require "arel/attributes/attribute"

module Arel # :nodoc: all
  module Attributes
    ###
    # Factory method to wrap a raw database +column+ to an Arel Attribute.
    def self.for(column)
      case column.type
      when :string, :text, :binary             then String
      when :integer                            then Integer
      when :float                              then Float
      when :decimal                            then Decimal
      when :date, :datetime, :timestamp, :time then Time
      when :boolean                            then Boolean
      else
        Undefined
      end
    end
  end
end

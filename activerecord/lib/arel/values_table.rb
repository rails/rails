# frozen_string_literal: true

module Arel # :nodoc: all
  class ValuesTable < Table
    attr_reader :rows, :column_aliases, :column_types

    # PostgreSQL uses column_types to cast the values and type the whole table
    def initialize(name, rows, column_aliases: nil, column_types: nil)
      super(name, as: name)
      @width = rows.first.size
      @rows = rows
      @column_aliases = column_aliases&.map(&:to_s)
      @column_types = column_types
    end

    # Pick default names so that :[] works even if aliases haven't been given
    def column_aliases_or_default_names
      @column_aliases_or_default_names ||= @column_aliases || (1..@width).map { |i| "column#{i}" }
    end

    def [](name, table = self)
      name = column_aliases_or_default_names[name] if name.is_a?(Integer)
      name = name.name if name.is_a?(Symbol)
      Arel::Attribute.new(table, name)
    end

    def hash
      super ^ [@rows, @column_aliases, @column_types].hash
    end

    def eql?(other)
      super(other) &&
        @rows == other.rows &&
        @column_aliases == other.column_aliases &&
        @column_types == other.column_types
    end
    alias :== :eql?
  end
end

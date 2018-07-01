# frozen_string_literal: true

module ActiveRecord::ConnectionAdapters::PostgreSQL
  ###
  # This class encapsulates a result returned from calling
  # {#exec_query}[rdoc-ref:ConnectionAdapters::DatabaseStatements#exec_query]
  # on the PostgreSQL connection adapter.
  class Result < ActiveRecord::Result
    include Enumerable

    attr_reader :columns

    def initialize(pg_result, adapter)
      @pg_result = pg_result
      @adapter = adapter
      @field_map = nil
      @length = nil
      @columns = @pg_result.fields
    end

    def initialize_copy(other)
    end

    def each
      return to_enum(:each) { length } unless block_given?

      l = length
      i = 0
      while i < l
        yield @pg_result.tuple(i)
        i += 1
      end
    end

    def [](i)
      @pg_result.tuple(i)
    end

    def column_type(name)
      if i = columns.index(name)
        ftype = @pg_result.ftype i
        fmod  = @pg_result.fmod i
        @adapter.get_oid_type ftype, fmod, name
      elsif block_given?
        yield
      else
        Type.default_value
      end
    end

    # Returns true if this result set includes the column named +name+
    def includes_column?(name)
      columns.include? name
    end

    def length
      @length ||= @pg_result.ntuples
    end

    def cast_values(type_overrides = {}) # :nodoc:
      if columns.one?
        # Separated to avoid allocating an array per row
        type = type_overrides.fetch(columns.first) { column_type(columns.first) }

        column_values(0).map { |value| type.deserialize(value) }
      else
        types = columns.map do |name|
          type_overrides.fetch(name) { column_type(name) }
        end

        @pg_result.values.map do |row|
          Array.new(row.size) { |i| types[i].deserialize(row[i]) }
        end
      end
    end

    def column_values(i)
      @pg_result.column_values(i)
    end

    def last
      return nil if length == 0
      self[length - 1]
    end

    def first
      return nil if length == 0
      self[0]
    end

    # Returns true if there are no records, otherwise false.
    def empty?
      length == 0
    end

    # Returns an array of hashes representing each row record.
    #
    # This method should be avoided, since it materializes the whole result set and is therefore slow.
    def to_a
      each.to_a.map(&:to_h)
    end

    alias :to_ary :to_a

    # Returns an array of arrays representing each row record values.
    #
    # This method should be avoided, since materializes the whole result set and is therefore slow.
    def rows
      @pg_result.values
    end
  end
end

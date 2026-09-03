# frozen_string_literal: true

# :markup: markdown

module ActiveModel
  class IndexedRow # :nodoc:
    class << self
      def [](hash)
        return hash if hash.is_a?(self)

        index = -1
        column_indexes = hash.transform_values { index += 1 }.freeze
        new(column_indexes, hash.values.freeze)
      end
    end

    attr_reader :indexes

    def initialize(indexes, row)
      @indexes = indexes
      @row = row
    end

    def size
      @indexes.size
    end
    alias_method :length, :size

    def each_key(&block)
      @indexes.each_key(&block)
    end

    def keys
      @indexes.keys
    end

    def ==(other)
      if other.is_a?(Hash)
        to_hash == other
      else
        super
      end
    end

    def key?(column)
      @indexes.key?(column)
    end

    def fetch(column)
      if index = @indexes[column]
        @row[index]
      elsif block_given?
        yield
      else
        raise KeyError, "key not found: #{column.inspect}"
      end
    end

    def [](column)
      if index = @indexes[column]
        @row[index]
      end
    end

    def to_h
      @indexes.transform_values { |index| @row[index] }
    end
    alias_method :to_hash, :to_h
  end
end

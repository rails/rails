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

    def values
      @row.dup
    end

    def values_at(*columns)
      columns.map! do |column|
        if index = @indexes[column]
          @row[index]
        end
      end
      columns
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

    def new_empty_mutable_row
      Mutable.new(@indexes)
    end

    class Mutable < self
      UNSET = Object.new.freeze
      private_constant :UNSET

      def initialize(indexes, row = nil)
        @indexes = indexes
        @row = row || Array.new(indexes.size, UNSET)
      end

      def size
        @indexes.size - @row.count(UNSET)
      end
      alias_method :length, :size

      def keys
        @indexes.reject { |k, v| UNSET.equal?(@row[v]) }.keys
      end

      def key?(column)
        index = @indexes[column]
        index && !UNSET.equal?(@row[index])
      end

      def values
        @row.reject { |v| UNSET.equal?(v) }
      end

      def values_at(*columns)
        columns.map! do |column|
          if index = @indexes[column]
            value = @row[index]
            UNSET.equal?(value) ? nil : value
          end
        end
        columns
      end

      def [](column)
        if index = @indexes[column]
          value = @row[index]
          return if UNSET.equal?(value)
          value
        end
      end

      def []=(column, value)
        if index = @indexes[column]
          @row[index] = value
        else
          raise KeyError, "key not found: #{column.inspect}"
        end
      end

      def fetch(column)
        if index = @indexes[column]
          value = @row[index]
          if UNSET.equal?(value)
            if block_given?
              yield
            else
              raise KeyError, "key not found: #{column.inspect}"
            end
          else
            value
          end
        elsif block_given?
          yield
        else
          raise KeyError, "key not found: #{column.inspect}"
        end
      end

      def to_h
        @indexes.transform_values { |index| @row[index] }.reject { |k, v| UNSET.equal?(v) }
      end
      alias_method :to_hash, :to_h
    end
  end
end

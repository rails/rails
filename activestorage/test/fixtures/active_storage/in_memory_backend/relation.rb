# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  class Relation
    include Enumerable

    def initialize(model, filters = [], exclusions = [])
      @model = model
      @filters = filters
      @exclusions = exclusions
    end

    def each(&block)
      to_a.each(&block)
    end

    def where(attributes = nil)
      if attributes
        self.class.new(@model, @filters + [ attributes ], @exclusions)
      else
        WhereChain.new(self)
      end
    end

    def not(attributes)
      self.class.new(@model, @filters, @exclusions + [ attributes ])
    end

    def order(*attributes)
      OrderedRelation.new(to_a.sort_by { |record| attributes.map { |attribute| order_value(record, attribute) } })
    end

    def find_by(attributes)
      where(attributes).first
    end

    def delete_all
      to_a.each(&:delete)
    end

    def destroy_all
      to_a.each(&:destroy)
    end

    def find_signed(...)
      @model.find_signed(...)
    end

    def find_signed!(...)
      @model.find_signed!(...)
    end

    def to_a
      @model.records.select { |record| matches?(record) }
    end

    private
      def matches?(record)
        @filters.all? { |filter| filter.all? { |key, value| matches_value?(record.public_send(key), value) } } &&
          @exclusions.none? { |filter| filter.any? { |key, value| matches_value?(record.public_send(key), value) } }
      end

      def matches_value?(actual, expected)
        expected.is_a?(Array) ? expected.include?(actual) : actual == expected
      end

      def order_value(record, attribute)
        value = record.public_send(attribute)
        return value if value

        attribute == :created_at ? Time.at(0) : 0
      end
  end

  class OrderedRelation
    include Enumerable

    def initialize(records)
      @records = records
    end

    def each(&block)
      @records.each(&block)
    end

    def to_a
      @records.dup
    end
  end

  class WhereChain
    def initialize(relation)
      @relation = relation
    end

    def not(attributes)
      @relation.not(attributes)
    end
  end
end

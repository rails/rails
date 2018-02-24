# frozen_string_literal: true
module Arel
  module Compatibility # :nodoc:
    class Wheres # :nodoc:
      include Enumerable

      module Value # :nodoc:
        attr_accessor :visitor
        def value
          visitor.accept self
        end

        def name
          super.to_sym
        end
      end

      def initialize engine, collection
        @engine     = engine
        @collection = collection
      end

      def each
        to_sql = Visitors::ToSql.new @engine

        @collection.each { |c|
          c.extend(Value)
          c.visitor = to_sql
          yield c
        }
      end
    end
  end
end

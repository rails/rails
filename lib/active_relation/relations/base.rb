module ActiveRelation
  module Relations
    class Base
      include Sql::Quoting
  
      module Iteration
        include Enumerable
    
        def each(&block)
          connection.select_all(to_s).each(&block)
        end
    
        def first
          connection.select_one(to_s)
        end
      end
      include Iteration
  
      module Operations
        def join(other)
          JoinOperation.new("INNER JOIN", self, other)
        end
  
        def outer_join(other)
          JoinOperation.new("LEFT OUTER JOIN", self, other)
        end
  
        def [](index)
          case index
          when Symbol
            attribute(index)
          when ::Range
            Range.new(self, index)
          end
        end
  
        def include?(attribute)
          Predicates::RelationInclusion.new(attribute, self)
        end
  
        def select(*predicates)
          Selection.new(self, *predicates)
        end
  
        def project(*attributes)
          Projection.new(self, *attributes)
        end
        
        def as(aliaz)
          Alias.new(self, aliaz)
        end
  
        def order(*attributes)
          Order.new(self, *attributes)
        end
    
        def rename(attribute, aliaz)
          Rename.new(self, attribute => aliaz)
        end
    
        def insert(record)
          Insertion.new(self, record)
        end
    
        def delete
          Deletion.new(self)
        end
    
        JoinOperation = Struct.new(:join_sql, :relation1, :relation2) do
          def on(*predicates)
            Join.new(join_sql, relation1, relation2, *predicates)
          end
        end
      end
      include Operations
  
      def to_sql(strategy = Sql::Select.new)
        strategy.select [
          "SELECT #{attributes.collect{ |a| a.to_sql(Sql::Projection.new) }.join(', ')}",
          "FROM #{table_sql}",
          (joins unless joins.blank?),
          ("WHERE #{selects.collect{|s| s.to_sql(Sql::Predicate.new)}.join("\n\tAND ")}" unless selects.blank?),
          ("ORDER BY #{orders.collect(&:to_sql)}" unless orders.blank?),
          ("LIMIT #{limit.to_sql}" unless limit.blank?),
          ("OFFSET #{offset.to_sql}" unless offset.blank?)
        ].compact.join("\n")
      end
      alias_method :to_s, :to_sql
    
      protected
      def connection
        ActiveRecord::Base.connection
      end

      def attributes; []  end
      def selects;    []  end
      def orders;     []  end
      def inserts;    []  end
      def joins;      nil end
      def limit;      nil end
      def offset;     nil end
      def alias;      nil end
    end
  end
end
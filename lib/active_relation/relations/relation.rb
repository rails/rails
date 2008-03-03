module ActiveRelation
  class Relation
    def session
      Session.new
    end

    module Enumerable
      include ::Enumerable

      def each(&block)
        session.read(self).each(&block)
      end

      def first
        session.read(self).first
      end
    end
    include Enumerable

    module Operations
      def join(other)
        JoinOperation.new("INNER JOIN", self, other)
      end

      def outer_join(other)
        JoinOperation.new("LEFT OUTER JOIN", self, other)
      end

      def [](index)
        case index
        when Symbol, String
          attribute_for_name(index)
        when ::Range
          Range.new(self, index)
        when Attribute, Expression
          attribute_for_attribute(index)
        end
      end

      def include?(attribute)
        RelationInclusion.new(attribute, self)
      end

      def select(*predicates)
        Selection.new(self, *predicates.collect {|p| p.bind(self)})
      end

      def project(*attributes)
        Projection.new(self, *attributes.collect {|a| a.bind(self)})
      end
      
      def as(aliaz)
        Alias.new(self, aliaz)
      end

      def order(*attributes)
        Order.new(self, *attributes.collect {|a| a.bind(self)})
      end
  
      def rename(attribute, aliaz)
        Rename.new(self, attribute => aliaz)
      end
        
      def aggregate(*expressions)
        AggregateOperation.new(self, expressions)
      end
      
      module Writes
        def insert(record)
          session.create Insertion.new(self, record.bind(self)); self
        end

        def update(assignments)
          session.update Update.new(self, assignments.bind(self)); self
        end

        def delete
          session.delete Deletion.new(self); self
        end
      end
      include Writes
  
      JoinOperation = Struct.new(:join_sql, :relation1, :relation2) do
        def on(*predicates)
          Join.new(join_sql, relation1, relation2, *predicates)
        end
      end
      
      AggregateOperation = Struct.new(:relation, :expressions) do
        def group(*groupings)
          Aggregation.new(relation, :expressions => expressions, :groupings => groupings)
        end
      end
    end
    include Operations
    
    def aggregation?
      false
    end
    
    def alias?
      false
    end
    
    def eql?(other)
      self == other
    end

    def to_sql(strategy = Sql::Relation.new(engine))
      strategy.select [
        "SELECT     #{attributes.collect{ |a| a.to_sql(Sql::Projection.new(engine)) }.join(', ')}",
        "FROM       #{table_sql}",
        (joins                                                                                      unless joins.blank?     ),
        ("WHERE     #{selects.collect{|s| s.to_sql(Sql::Selection.new(engine))}.join("\n\tAND ")}"  unless selects.blank?   ),
        ("ORDER BY  #{orders.collect(&:to_sql)}"                                                    unless orders.blank?    ),
        ("GROUP BY  #{groupings.collect(&:to_sql)}"                                                 unless groupings.blank? ),
        ("LIMIT     #{limit}"                                                                       unless limit.blank?     ),
        ("OFFSET    #{offset}"                                                                      unless offset.blank?    )
      ].compact.join("\n"), self.alias
    end
    alias_method :to_s, :to_sql
        
    def attribute_for_name(name)
      attributes.detect { |a| a.alias_or_name.to_s == name.to_s }
    end
    
    def attribute_for_attribute(attribute)
      attributes.detect { |a| a =~ attribute }
    end
    
    def bind(relation)
      self
    end
    
    def strategy
      Sql::Predicate.new(engine)
    end

    def attributes;  []  end
    def selects;     []  end
    def orders;      []  end
    def inserts;     []  end
    def groupings;   []  end
    def joins;       nil end
    def limit;       nil end
    def offset;      nil end
    def alias;       nil end
  end
end
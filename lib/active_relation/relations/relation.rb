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
        case other
        when String
          Join.new(other, self)
        when Relation
          JoinOperation.new("INNER JOIN", self, other)
        end
      end

      def outer_join(other)
        JoinOperation.new("LEFT OUTER JOIN", self, other)
      end

      def [](index)
        case index
        when Symbol, String
          attribute_for_name(index)
        when Attribute, Expression
          attribute_for_attribute(index)
        end
      end

      def select(*predicates)
        predicates.all?(&:blank?) ? self : Selection.new(self, *predicates)
      end

      def project(*attributes)
        attributes.all?(&:blank?) ? self : Projection.new(self, *attributes)
      end
      
      def as(aliaz)
        aliaz.blank?? self : Alias.new(self, aliaz)
      end

      def order(*attributes)
        attributes.all?(&:blank?) ? self : Order.new(self, *attributes)
      end
      
      def take(taken)
        taken.blank?? self : Take.new(self, taken)
      end
      
      def skip(skipped)
        skipped.blank?? self : Skip.new(self, skipped)
      end
  
      def rename(attribute, aliaz)
        Rename.new(self, attribute => aliaz)
      end
        
      def aggregate(*expressions)
        AggregateOperation.new(self, expressions)
      end
      
      module Writes
        def insert(record)
          session.create Insertion.new(self, record); self
        end

        def update(assignments)
          session.update Update.new(self, assignments); self
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
    
    module Externalizable
      def aggregation?
        false
      end
    
      def alias?
        false
      end
    end
    include Externalizable
    
    def to_sql(formatter = Sql::SelectStatement.new(engine))
      formatter.select [
        "SELECT     #{attributes.collect { |a| a.to_sql(Sql::SelectClause.new(engine)) }.join(', ')}",
        "FROM       #{table_sql}",
        (joins                                                                                          unless joins.blank?     ),
        ("WHERE     #{selects.collect { |s| s.to_sql(Sql::WhereClause.new(engine)) }.join("\n\tAND ")}" unless selects.blank?   ),
        ("ORDER BY  #{orders.collect { |o| o.to_sql(Sql::OrderClause.new(engine)) }.join(', ')}"        unless orders.blank?    ),
        ("GROUP BY  #{groupings.collect(&:to_sql)}"                                                     unless groupings.blank? ),
        ("LIMIT     #{taken}"                                                                           unless taken.blank?     ),
        ("OFFSET    #{skipped}"                                                                         unless skipped.blank?   )
      ].compact.join("\n"), self.alias
    end
    alias_method :to_s, :to_sql
    
    def inclusion_predicate_sql
      "IN"
    end
    
    def call(connection = engine.connection)
      connection.select_all(to_sql)
    end
       
    module AttributeAccessors 
      def attribute_for_name(name)
        attributes.detect { |a| a.alias_or_name.to_s == name.to_s }
      end
    
      def attribute_for_attribute(attribute)
        attributes.detect { |a| a =~ attribute }
      end
    end
    include AttributeAccessors
    
    def bind(relation)
      self
    end
    
    def format(object)
      object.to_sql(Sql::WhereCondition.new(engine))
    end

    def attributes;  []  end
    def selects;     []  end
    def orders;      []  end
    def inserts;     []  end
    def groupings;   []  end
    def joins;       nil end
    def taken;       nil end
    def skipped;     nil end
    def alias;       nil end
  end
end
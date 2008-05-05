module Arel
  class Relation
    def session
      Session.new
    end
    
    def name_for(relation)
      relation.name
    end
    
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select [
        "SELECT     #{attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }.join(', ')}",
        "FROM       #{table_sql(Sql::TableReference.new(self))}",
        (joins(Sql::TableReference.new(self))                                                           unless joins.blank?     ),
        ("WHERE     #{selects.collect { |s| s.to_sql(Sql::WhereClause.new(self)) }.join("\n\tAND ")}"   unless selects.blank?   ),
        ("ORDER BY  #{orders.collect { |o| o.to_sql(Sql::OrderClause.new(self)) }.join(', ')}"          unless orders.blank?    ),
        ("GROUP BY  #{groupings.collect(&:to_sql)}"                                                     unless groupings.blank? ),
        ("LIMIT     #{taken}"                                                                           unless taken.blank?     ),
        ("OFFSET    #{skipped}"                                                                         unless skipped.blank?   )
      ].compact.join("\n"), name
    end
    alias_method :to_s, :to_sql

    def table_sql(formatter = Sql::TableReference.new(self))
      if table.aggregation?
        table.to_sql(Sql::TableReference.new(self))
      else
        table.table_sql(Sql::TableReference.new(self))
      end
    end
    
    def inclusion_predicate_sql
      "IN"
    end
    
    def call(connection = engine.connection)
      results = connection.execute(to_sql)
      rows = []
      results.each do |row|
        rows << attributes.zip(row).to_hash
      end
      rows
    end
    
    def bind(relation)
      self
    end
    
    def christener
      @christener ||= Sql::Christener.new
    end
    
    def aggregation?
      false
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

    module Operable
      def join(other = nil, join_type = "INNER JOIN")
        case other
        when String
          Join.new(other, self)
        when Relation
          JoinOperation.new(join_type, self, other)
        else
          self
        end
      end

      def outer_join(other = nil)
        join(other, "LEFT OUTER JOIN")
      end
      
      def select(*predicates)
        predicates.all?(&:blank?) ? self : Selection.new(self, *predicates)
      end

      def project(*attributes)
        attributes.all?(&:blank?) ? self : Projection.new(self, *attributes)
      end
      
      def alias
        Alias.new(self)
      end

      def order(*attributes)
        attributes.all?(&:blank?) ? self : Order.new(self, *attributes)
      end
      
      def take(taken = nil)
        taken.blank?? self : Take.new(self, taken)
      end
      
      def skip(skipped = nil)
        skipped.blank?? self : Skip.new(self, skipped)
      end
  
      def group(*groupings)
        groupings.all?(&:blank?) ? self : Grouping.new(self, *groupings)
      end
      
      module Writable
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
      include Writable
  
      JoinOperation = Struct.new(:join_sql, :relation1, :relation2) do
        def on(*predicates)
          Join.new(join_sql, relation1, relation2, *predicates)
        end
      end
    end
    include Operable
    
    module AttributeAccessable
      def [](index)
        case index
        when Symbol, String
          attribute_for_name(index)
        when Attribute, Expression
          attribute_for_attribute(index)
        when Array
          index.collect { |i| self[i] }
        end
      end
      
      def attribute_for_name(name)
        attributes.detect { |a| a.alias_or_name.to_s == name.to_s }
      end

      def attribute_for_attribute(attribute)
        attributes.select { |a| a =~ attribute }.min do |a1, a2|
          (attribute % a1).size <=> (attribute % a2).size
        end
      end
    end
    include AttributeAccessable

    module DefaultOperations
      def attributes;             []  end
      def selects;                []  end
      def orders;                 []  end
      def inserts;                []  end
      def groupings;              []  end
      def joins(formatter = nil); nil end
      def taken;                  nil end
      def skipped;                nil end
    end
    include DefaultOperations
  end
end
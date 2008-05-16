module Arel
  class Relation
    def session
      Session.new
    end
    
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select [
        "SELECT     #{attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }.join(', ')}",
        "FROM       #{table_sql(Sql::TableReference.new(self))}",
        (joins(self)                                                                                    unless joins(self).blank? ),
        ("WHERE     #{selects.collect { |s| s.to_sql(Sql::WhereClause.new(self)) }.join("\n\tAND ")}"   unless selects.blank?     ),
        ("ORDER BY  #{orders.collect { |o| o.to_sql(Sql::OrderClause.new(self)) }.join(', ')}"          unless orders.blank?      ),
        ("GROUP BY  #{groupings.collect { |g| g.to_sql(Sql::GroupClause.new(self)) }.join(', ')}"       unless groupings.blank?   ),
        ("LIMIT     #{taken}"                                                                           unless taken.blank?       ),
        ("OFFSET    #{skipped}"                                                                         unless skipped.blank?     )
      ].compact.join("\n"), name
    end
    alias_method :to_s, :to_sql
    
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
          find_attribute_matching_name(index)
        when Attribute, Expression
          find_attribute_matching_attribute(index)
        when Array
          index.collect { |i| self[i] }
        end
      end
      
      def find_attribute_matching_name(name)
        attributes.detect { |a| a.named?(name) }
      end
      
      # TESTME - added original_attribute because of AR
      def find_attribute_matching_attribute(attribute)
        attributes.select { |a| a.match?(attribute) }.max do |a1, a2|
          (attribute / a1.original_attribute) <=> (attribute / a2.original_attribute)
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
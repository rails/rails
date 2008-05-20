module Arel
  class Relation
    def session
      Session.new
    end
    
    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select select_sql, self
    end
    alias_method :to_s, :to_sql
    
    def select_sql
      [
        "SELECT     #{attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }.join(', ')}",
        "FROM       #{table_sql(Sql::TableReference.new(self))}",
        (joins(self)                                                                                    unless joins(self).blank? ),
        ("WHERE     #{wheres   .collect { |w| w.to_sql(Sql::WhereClause.new(self)) }.join("\n\tAND ")}" unless wheres.blank?      ),
        ("ORDER BY  #{orders   .collect { |o| o.to_sql(Sql::OrderClause.new(self)) }.join(', ')}"       unless orders.blank?      ),
        ("GROUP BY  #{groupings.collect { |g| g.to_sql(Sql::GroupClause.new(self)) }.join(', ')}"       unless groupings.blank?   ),
        ("LIMIT     #{taken}"                                                                           unless taken.blank?       ),
        ("OFFSET    #{skipped}"                                                                         unless skipped.blank?     )
      ].compact.join("\n")
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
      def join(other_relation = nil, join_type = "INNER JOIN")
        case other_relation
        when String
          Join.new(other_relation, self)
        when Relation
          JoinOperation.new(join_type, self, other_relation)
        else
          self
        end
      end

      def outer_join(other_relation = nil)
        join(other_relation, "LEFT OUTER JOIN")
      end
      
      [:where, :project, :order, :take, :skip, :group].each do |operation_name|
        operation = <<-OPERATION
          def #{operation_name}(*arguments, &block)
            arguments.all?(&:blank?) && !block_given?? self : #{operation_name.to_s.classify}.new(self, *arguments, &block)
          end
        OPERATION
        class_eval operation, __FILE__, __LINE__
      end

      def alias
        Alias.new(self)
      end
      
      module Writable
        def insert(record)
          session.create Insert.new(self, record); self
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
      
      def find_attribute_matching_attribute(attribute)
        matching_attributes(attribute).max do |a1, a2|
          (a1.original_attribute / attribute) <=> (a2.original_attribute / attribute)
        end
      end
      
      private
      def matching_attributes(attribute)
        (@matching_attributes ||= attributes.inject({}) do |hash, a|
          (hash[a.root] ||= []) << a
          hash
        end)[attribute.root] || []
      end
      
      def has_attribute?(attribute)
        !matching_attributes(attribute).empty?
      end
    end
    include AttributeAccessable

    module DefaultOperations
      def attributes;             []  end
      def wheres;                 []  end
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
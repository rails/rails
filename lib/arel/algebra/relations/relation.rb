module Arel
  module Relation
    @@connection_tables_primary_keys = {}

    attr_reader :count

    def session
      Session.instance
    end

    def join?
      false
    end

    def call
      engine.read(self)
    end

    def bind(relation)
      self
    end

    def externalize
      @externalized ||= externalizable?? Externalization.new(self) : self
    end

    def externalizable?
      false
    end

    def compiler
      @compiler ||=  begin
        Arel::SqlCompiler.const_get("#{engine.adapter_name}Compiler").new(self)
      rescue
        Arel::SqlCompiler::GenericCompiler.new(self)
      end
    end

    def to_sql(formatter = Sql::SelectStatement.new(self))
      formatter.select compiler.select_sql, self
    end

    def christener
      @christener ||= Sql::Christener.new
    end

    def inclusion_predicate_sql
      "IN"
    end

    def exclusion_predicate_sql
      "NOT IN"
    end

    def primary_key
      connection_id = engine.connection.object_id
      if @@connection_tables_primary_keys[connection_id] && @@connection_tables_primary_keys[connection_id].has_key?(table.name)
        @@connection_tables_primary_keys[connection_id][table.name]
      else
        @@connection_tables_primary_keys[connection_id] ||= {}
        @@connection_tables_primary_keys[connection_id][table.name] = engine.connection.primary_key(table.name)
      end
    end

    def select_clauses
      attributes.collect { |a| a.to_sql(Sql::SelectClause.new(self)) }
    end

    def from_clauses
      sources.blank? ? table_sql(Sql::TableReference.new(self)) : sources
    end

    def where_clauses
      wheres.collect { |w|
        case w
        when Value
          w.value
        else # FIXME: why do we have to pass in a whereclause?
          w.to_sql(Sql::WhereClause.new(self))
        end
      }
    end

    def group_clauses
      groupings.collect { |g| g.to_sql(Sql::GroupClause.new(self)) }
    end

    def having_clauses
      havings.collect { |g| g.to_sql(Sql::HavingClause.new(self)) }
    end

    def order_clauses
      orders.collect { |o| o.to_sql(Sql::OrderClause.new(self)) }
    end

    module Enumerable
      include ::Enumerable

      def each
        session.read(self).each { |e| yield e }
      end

      def first
        session.read(self).first
      end
    end
    include Enumerable

    module Operable
      def join(other_relation = nil, join_class = InnerJoin)
        case other_relation
        when String
          StringJoin.new(self, other_relation)
        when Relation
          JoinOperation.new(join_class, self, other_relation)
        else
          self
        end
      end

      def outer_join(other_relation = nil)
        join(other_relation, OuterJoin)
      end

      %w{
        where project order skip group having
      }.each do |operation_name|
        class_eval <<-OPERATION, __FILE__, __LINE__
          def #{operation_name}(*arguments)
            arguments.all? { |x| x.blank? } ?
              self : #{operation_name.capitalize}.new(self, *arguments)
          end
        OPERATION
      end

      def take thing
        Take.new self, thing
      end

      def from thing
        From.new self, thing
      end

      def lock(locking = nil)
        Lock.new(self, locking)
      end

      def alias
        Alias.new(self)
      end

      module Writable
        def insert(record)
          session.create Insert.new(self, record)
        end

        def update(assignments)
          session.update Update.new(self, assignments)
        end

        def delete
          session.delete Deletion.new(self)
        end
      end
      include Writable

      JoinOperation = Struct.new(:join_class, :relation1, :relation2) do
        def on(*predicates)
          join_class.new(relation1, relation2, *predicates)
        end
      end
    end
    include Operable

    def [](index)
      attributes[index]
    end

    def find_attribute_matching_name(name)
      attributes.detect { |a| a.named?(name) } || Attribute.new(self, name)
    end

    def find_attribute_matching_attribute(attribute)
      matching_attributes(attribute).max do |a1, a2|
        (a1.original_attribute / attribute) <=> (a2.original_attribute / attribute)
      end
    end

    def position_of(attribute)
      (@position_of ||= Hash.new do |h, attribute|
        h[attribute] = attributes.index(self[attribute])
      end)[attribute]
    end

    private
    def matching_attributes(attribute)
      (@matching_attributes ||= attributes.inject({}) do |hash, a|
        (hash[a.is_a?(Value) ? a.value : a.root] ||= []) << a
        hash
      end)[attribute.root] || []
    end

    def has_attribute?(attribute)
      !matching_attributes(attribute).empty?
    end

    module DefaultOperations
      def attributes;             Header.new  end
      def projections;            []          end
      def wheres;                 []          end
      def orders;                 []          end
      def inserts;                []          end
      def groupings;              []          end
      def havings;                []          end
      def joins(formatter = nil); nil         end # FIXME
      def taken;                  nil         end
      def skipped;                nil         end
      def sources;                []          end
      def locked;                 []          end
    end
    include DefaultOperations
  end
end

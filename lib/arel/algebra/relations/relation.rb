module Arel
  module Relation
    include Enumerable

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

    def to_sql(formatter = nil)
      sql = compiler.select_sql

      return sql unless formatter
      formatter.select sql, self
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
      attributes.map { |a|
        case a
        when Value
          a.value
        else
          a.to_sql(Sql::SelectClause.new(self))
        end
      }
    end

    def from_clauses
      sources.empty? ? table_sql : sources
    end

    def where_clauses
      wheres.map { |w| w.value }
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

    def each
      session.read(self).each { |e| yield e }
    end

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
        having group order
    }.each do |op|
      class_eval <<-OPERATION, __FILE__, __LINE__
          def #{op}(*args)
            args.all? { |x| x.blank? } ? self : #{op.capitalize}.new(self, args)
          end
      OPERATION
    end

    def project *args
      args.empty? ? self : Project.new(self, args)
    end

    def where clause = nil
      clause ? Where.new(self, Array(clause)) : self
    end

    def skip thing = nil
      thing ? Skip.new(self, thing) : self
    end

    def take count
      Take.new self, count
    end

    def from thing
      From.new self, thing
    end

    def lock(locking = true)
      Lock.new(self, locking)
    end

    def alias
      Alias.new(self)
    end

    def insert(record)
      session.create Insert.new(self, record)
    end

    def update(assignments)
      session.update Update.new(self, assignments)
    end

    def delete
      session.delete Deletion.new(self)
    end

    JoinOperation = Struct.new(:join_class, :relation1, :relation2) do
      def on(*predicates)
        join_class.new(relation1, relation2, *predicates)
      end
    end

    def [](index)
      attributes[index]
    end

    def find_attribute_matching_name(name)
      attributes.detect { |a| a.named?(name) } || Attribute.new(self, name)
    end

    def position_of(attribute)
      @position_of ||= {}

      return @position_of[attribute] if @position_of.key? attribute

      @position_of[attribute] = attributes.index(attributes[attribute])
    end

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
end

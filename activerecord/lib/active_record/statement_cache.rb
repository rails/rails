module ActiveRecord

  # Statement cache is used to cache a single statement in order to avoid creating the AST again.
  # Initializing the cache is done by passing the statement in the initialization block:
  #
  #   cache = ActiveRecord::StatementCache.new do
  #     Book.where(name: "my book").limit(100)
  #   end
  #
  # The cached statement is executed by using the +execute+ method:
  #
  #   cache.execute
  #
  # The relation returned by the block is cached, and for each +execute+ call the cached relation gets duped.
  # Database is queried when +to_a+ is called on the relation.
  class StatementCache
    Substitute = Struct.new :name

    class Query
      def initialize(connection, sql)
        @connection = connection
        @sql = sql
      end

      def sql_for(binds)
        @sql
      end
    end

    class PartialQuery < Query
      def sql_for(binds)
        @sql.gsub(/\?/) { @connection.quote(*binds.shift.reverse) }
      end
    end

    def self.query(connection, visitor, ast)
      Query.new connection, visitor.accept(ast)
    end

    def self.partial_query(connection, visitor, ast)
      sql = visitor.accept(ast) { "?" }
      PartialQuery.new connection, sql
    end

    class Params
      def [](name); Substitute.new name; end
    end

    class BindMap
      def initialize(bind_values)
        @value_map   = {}
        @bind_values = bind_values

        bind_values.each_with_index do |(_, value), i|
          if Substitute === value
            @value_map[value.name] = i
          end
        end
      end

      def bind(values)
        bvs = @bind_values.map { |pair| pair.dup }
        values.each { |k,v| bvs[@value_map[k]][1] = v }
        bvs
      end
    end

    def initialize(block = Proc.new)
      @mutex    = Mutex.new
      @relation = nil
      @sql      = nil
      @binds    = nil
      @block    = block
      @query_builder = nil
      @params   = Params.new
    end

    def execute(params)
      rel = relation @params

      arel        = rel.arel
      klass       = rel.klass
      bind_map    = binds rel
      bind_values = bind_map.bind params

      builder = query_builder klass.connection, arel
      sql = builder.sql_for bind_values

      klass.find_by_sql sql, bind_values
    end
    alias :call :execute

    private
    def binds(rel)
      @binds || @mutex.synchronize { @binds ||= BindMap.new rel.bind_values }
    end

    def query_builder(connection, arel)
      @query_builder || @mutex.synchronize {
        @query_builder ||= connection.cacheable_query(arel)
      }
    end

    def sql(klass, arel, bv)
      @sql || @mutex.synchronize {
        @sql ||= klass.connection.to_sql arel, bv
      }
    end

    def relation(values)
      @relation || @mutex.synchronize { @relation ||= @block.call(values) }
    end
  end
end

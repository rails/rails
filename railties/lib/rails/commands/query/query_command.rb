# frozen_string_literal: true

require "json"
require "rails/command/environment_argument"

module Rails
  module Command
    class QueryCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :sql, type: :boolean,
        desc: "Treat input as raw SQL instead of an ActiveRecord expression"

      class_option :database, aliases: "--db", type: :string,
        desc: "Database configuration to use (e.g. primary_replica)"

      class_option :page, type: :numeric, default: 1,
        desc: "Page number for paginated results"

      class_option :per, type: :numeric, default: 100,
        desc: "Results per page (max 10000)"

      desc "query [EXPRESSION]", "Run a read-only query against the database"
      def perform(expression = nil, *args)
        boot_application!
        Rails.application.load_runner

        ActiveSupport::Notifications.instrument("query.rails", expression: expression) do
          case expression
          when "schema"
            run_schema(args.first)
          when "models"
            run_models
          when "explain"
            run_explain(args.first)
          else
            run_query(expression)
          end
        end
      rescue StandardError, SyntaxError, NotImplementedError => e
        output_error(e.message)
        exit 1
      end

      private
        def run_query(expression)
          expression = resolve_expression(expression)
          page = [ options[:page], 1 ].max
          per = [ [ options[:per], 1 ].max, 10_000 ].min

          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = if options[:sql]
            with_readonly_connection do |connection|
              execute_sql(connection: connection, sql: expression, page: page, per: per)
            end
          else
            execute_ar(expression: expression, page: page, per: per)
          end
          elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(1)

          say format_result(**result, elapsed_ms: elapsed_ms, page: page, per: per)
        end

        def run_schema(table = nil)
          with_readonly_connection do |connection|
            if table
              say format_table_detail(connection, table)
            else
              say format_table_list(connection)
            end
          end
        end

        def run_models
          Rails.application.eager_load!

          models = ActiveRecord::Base.descendants
            .reject(&:abstract_class?)
            .select { |model| model.table_name.present? }
            .sort_by(&:name)

          data = models.map do |model|
            {
              model: model.name,
              table_name: model.table_name,
              associations: format_associations(model)
            }
          end

          say JSON.generate(data)
        end

        def run_explain(expression = nil)
          expression = resolve_expression(expression)

          if options[:sql]
            with_readonly_connection do |connection|
              result = connection.select_all("EXPLAIN #{expression}")
              say format_result(columns: result.columns, rows: result.rows, sql: "EXPLAIN #{expression}")
            end
          else
            relation = eval(expression, TOPLEVEL_BINDING, "(query)", 1)
            sql = relation.to_sql
            with_readonly_connection_for(relation.model.connection_class_for_self) do |connection|
              result = connection.select_all("EXPLAIN #{sql}")
              say format_result(columns: result.columns, rows: result.rows, sql: "EXPLAIN #{sql}")
            end
          end
        end

        def with_readonly_connection(&block)
          with_readonly_connection_for(ActiveRecord::Base, &block)
        end

        def with_readonly_connection_for(connection_class, &block)
          if options[:database]
            with_explicit_database(options[:database], &block)
          elsif reading_role_available?(connection_class)
            connection_class.connected_to(role: :reading) do
              connection_class.with_connection(&block)
            end
          else
            connection_class.while_preventing_writes do
              connection_class.with_connection(&block)
            end
          end
        end

        def with_explicit_database(database)
          original = ActiveRecord::Base.connection_db_config
          begin
            ActiveRecord::Base.establish_connection(database.to_sym)
            ActiveRecord::Base.while_preventing_writes do
              yield ActiveRecord::Base.lease_connection
            end
          ensure
            ActiveRecord::Base.establish_connection(original)
          end
        end

        def reading_role_available?(connection_class)
          connection_class.connected_to(role: :reading) do
            connection_class.lease_connection
          end
          true
        rescue ActiveRecord::ConnectionNotEstablished
          false
        end

        def execute_ar(expression:, page:, per:)
          result = eval(expression, TOPLEVEL_BINDING, "(query)", 1)

          case result
          when ActiveRecord::Relation
            relation = result.offset((page - 1) * per).limit(per + 1)
            sql = relation.to_sql
            with_readonly_connection_for(relation.model.connection_class_for_self) do |connection|
              ar_result = connection.select_all(sql)
              truncated = ar_result.rows.length > per
              { columns: ar_result.columns, rows: ar_result.rows.first(per), sql: sql, truncated: truncated }
            end
          when ActiveRecord::Result
            { columns: result.columns, rows: result.rows, sql: expression, truncated: false }
          when Hash
            rows = result.map { |key, val| [ key, val ] }
            { columns: [ "key", "value" ], rows: rows, sql: expression, truncated: false }
          when Array
            rows = result.map { |val| Array(val) }
            cols = Array.new(rows.first&.length.to_i) { |i| "column_#{i}" }
            { columns: cols, rows: rows, sql: expression, truncated: false }
          else
            { columns: [ "result" ], rows: [ [ result ] ], sql: expression, truncated: false }
          end
        end

        def execute_sql(connection:, sql:, page:, per:)
          unless sql.gsub(/--.*$|\/\*.*?\*\//m, "").match?(/\bLIMIT\b/i)
            offset = (page - 1) * per
            sql = "#{sql.rstrip.chomp(';')} LIMIT #{per + 1}"
            sql += " OFFSET #{offset}" if offset > 0
          end

          ar_result = connection.select_all(sql)
          truncated = ar_result.rows.length > per
          { columns: ar_result.columns, rows: ar_result.rows.first(per), sql: sql, truncated: truncated }
        end

        def format_result(columns:, rows:, sql:, elapsed_ms: 0, page: 1, per: rows.length, truncated: false)
          JSON.generate({
            columns: columns,
            rows: rows,
            meta: {
              row_count: rows.length,
              query_time_ms: elapsed_ms,
              page: page,
              per_page: per,
              has_more: truncated,
              sql: sql
            }
          })
        end

        def format_table_list(connection)
          tables = connection.tables.sort
          rows = tables.map { |table| [ table ] }

          format_result(columns: [ "table_name" ], rows: rows, sql: "")
        end

        def format_table_detail(connection, table)
          raise ArgumentError, "Table '#{table}' does not exist" unless connection.table_exists?(table)

          columns = connection.columns(table)
          indexes = connection.indexes(table)
          model = model_for_table(table)

          JSON.generate({
            table: table,
            columns: columns.map do |col|
              { name: col.name, type: col.sql_type, null: col.null, default: col.default }
            end,
            indexes: indexes.map do |idx|
              { name: idx.name, columns: idx.columns, unique: idx.unique }
            end,
            enums: model&.defined_enums.presence,
            associations: format_associations(model)
          }.compact)
        end

        def model_for_table(table)
          Rails.application.eager_load!

          ActiveRecord::Base.descendants.find do |klass|
            !klass.abstract_class? && klass.table_name == table
          end
        end

        def format_associations(model)
          return unless model

          model.reflect_on_all_associations.map do |assoc|
            hash = {
              type: assoc.macro,
              name: assoc.name,
              class_name: assoc.class_name
            }
            hash[:foreign_key] = assoc.foreign_key if assoc.respond_to?(:foreign_key)
            hash[:through] = assoc.through_reflection.name if assoc.through_reflection?
            hash
          end
        end

        def resolve_expression(expression)
          if expression == "-" || (expression.nil? && !$stdin.tty?)
            $stdin.read.strip
          elsif expression
            expression
          else
            raise ArgumentError, "No query expression provided. Run '#{self.class.executable} -h' for help."
          end
        end

        def output_error(message)
          error JSON.generate({
            error: message,
            meta: { query_time_ms: 0 }
          })
        end
    end
  end
end

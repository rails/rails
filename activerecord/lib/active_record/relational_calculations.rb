module ActiveRecord
  module RelationalCalculations

    def count(*args)
      column_name, options = construct_count_options_from_args(*args)
      distinct = options[:distinct] ? true : false

      column = if @klass.column_names.include?(column_name.to_s)
        Arel::Attribute.new(@relation.table, column_name)
      else
        Arel::SqlLiteral.new(column_name == :all ? "*" : column_name.to_s)
      end

      relation = select(column.count(distinct))
      @klass.connection.select_value(relation.to_sql).to_i
    end

    private

    def construct_count_options_from_args(*args)
      options     = {}
      column_name = :all

      # We need to handle
      #   count()
      #   count(:column_name=:all)
      #   count(options={})
      #   count(column_name=:all, options={})
      #   selects specified by scopes

      # TODO : relation.projections only works when .select() was last in the chain. Fix it!
      case args.size
      when 0
        column_name = @relation.send(:select_clauses).join(', ') if @relation.respond_to?(:projections) && @relation.projections.present?
      when 1
        if args[0].is_a?(Hash)
          column_name = @relation.send(:select_clauses).join(', ') if @relation.respond_to?(:projections) && @relation.projections.present?
          options = args[0]
        else
          column_name = args[0]
        end
      when 2
        column_name, options = args
      else
        raise ArgumentError, "Unexpected parameters passed to count(): #{args.inspect}"
      end

      [column_name || :all, options]
    end

  end
end

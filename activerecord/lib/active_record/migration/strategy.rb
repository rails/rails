module ActiveRecord::Migration::Strategy
  class Version1

    def connection_dispatch(connection, method, *args, &block)
      args = connection_arguments method, args
      connection.public_send method, *args, &block
    end

    private
    def connection_arguments(method, args)
      unless args.empty? || [:execute, :enable_extension, :disable_extension].include?(method)
        args[0] = ActiveRecord::Migrator.proper_table_name(args.first)
        if [:rename_table, :add_foreign_key].include?(method) ||
          (method == :remove_foreign_key && !args.second.is_a?(Hash))
          args[1] = ActiveRecord::Migrator.proper_table_name(args.second)
        end
      end
      args
    end
  end

  class Version2 < Version1

    private
    def connection_arguments(method, args)
      if method == :references
        options = args.extract_options!
        options.reverse_merge! index: true, foreign_key: true
        args.push options
      end

      super
    end
  end
end

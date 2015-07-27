module ActiveRecord::Migration::Strategy
  module Version1
    def self.connection_arguments(method, args)
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

  module Version2
    def self.connection_arguments(method, args)
      if method == :references
        options = args.extract_options!
        options.reverse_merge! index: true, foreign_key: true
        args.push options
      end

      Version1.connection_arguments method, args
    end
  end
end

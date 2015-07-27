module ActiveRecord::Migration::Strategy
  VERSIONS = {}
  # return previous known version if current one has no corresponding strategy
  VERSIONS.default_proc = ->(hash, version) do
    (hash.find {|key,_| key <= version } || [Base]).last
  end

  class Base
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

  VERSIONS[5.0] = Class.new Base do
    private
    def connection_arguments(method, args)
      if method == :add_reference
        options = args.extract_options!
        options.reverse_merge! index: true
        args.push options
      end

      super
    end
  end
end

# frozen_string_literal: true

module ActiveRecord
  class Migration
    module Compatibility # :nodoc: all
      def self.find(version)
        version = version.to_s
        name = "V#{version.tr('.', '_')}"
        unless const_defined?(name)
          versions = constants.grep(/\AV[0-9_]+\z/).map { |s| s.to_s.delete("V").tr("_", ".").inspect }
          raise ArgumentError, "Unknown migration version #{version.inspect}; expected one of #{versions.sort.join(', ')}"
        end
        const_get(name)
      end

      def self.framework_classes
        constants.grep(/\AV\d+_\d+\z/).map { |c| const_get(c) }.uniq.freeze
      end

      def self.target_class_for(klass)
        @target_cache ||= ObjectSpace::WeakMap.new
        return @target_cache[klass] if @target_cache[klass]

        framework = framework_classes
        result = klass
        until framework.include?(result.superclass)
          break unless result.superclass <= ActiveRecord::Migration
          result = result.superclass
        end
        @target_cache[klass] = result
        result
      end

      class ConflictError < ActiveRecord::MigrationError
      end

      def self.apply(target, mod, adapter_name:)
        @applied ||= ObjectSpace::WeakMap.new
        current = @applied[target]

        if current
          current_name, current_mod = current
          if current_name != adapter_name && !current_mod.equal?(mod)
            raise ConflictError, <<~MSG.squish
              Migration class #{target.name || target.inspect} has already been
              associated with adapter compatibility for #{current_name.inspect};
              cannot also apply #{adapter_name.inspect}. Use a distinct migration
              base class per adapter type; see
              https://guides.rubyonrails.org/active_record_multiple_databases.html#sharing-migration-helpers-across-different-database-adapters
              for the recommended pattern.
            MSG
          end
        else
          @applied[target] = [adapter_name, mod]
          target.include(mod) unless target.include?(mod)
        end
      end

      module Versioned
        def module_for(migration_class)
          target = Compatibility.target_class_for(migration_class)
          @module_cache ||= ObjectSpace::WeakMap.new
          cached = @module_cache[target]
          return cached if cached

          mods = version_pairs
            .filter_map { |compat_class, mod| mod if target <= compat_class }
          return nil if mods.empty?

          assembled = Module.new { mods.reverse_each { |m| include m } }
          @module_cache[target] = assembled
          assembled
        end

        private
          def version_pairs
            @version_pairs ||= constants.grep(/\AV\d+_\d+\z/)
              .sort_by { |name| name.to_s.delete("V").split("_").map(&:to_i) }
              .map { |name| [Compatibility.const_get(name), const_get(name)] }
          end
      end

      # This file exists to ensure that old migrations run the same way they did before a Rails upgrade.
      # e.g. if you write a migration on Rails 6.1, then upgrade to Rails 7, the migration should do the same thing to your
      # database as it did when you were running Rails 6.1
      #
      # "Current" is an alias for `ActiveRecord::Migration`, it represents the current Rails version.
      # New migration functionality that will never be backward compatible should be added directly to `ActiveRecord::Migration`.
      #
      # There are classes for each prior Rails version. Each class descends from the *next* Rails version, so:
      # 5.2 < 6.0 < 6.1 < 7.0 < 7.1 < 7.2 < 8.0 < 8.1 < 8.2
      #
      # If you are introducing new migration functionality that should only apply from Rails 7 onward, then you should
      # find the class that immediately precedes it (6.1), and override the relevant migration methods to undo your changes.
      #
      # For example, Rails 6 added a default value for the `precision` option on datetime columns. So in this file, the `V5_2`
      # class sets the value of `precision` to `nil` if it's not explicitly provided. This way, the default value will not apply
      # for migrations written for 5.2, but will for migrations written for 6.0.
      V8_2 = Current

      class V8_1 < V8_2
      end

      class V8_0 < V8_1
        module RemoveForeignKeyColumnMatch
          def remove_foreign_key(*args, **options)
            options[:_skip_column_match] = true
            super
          end
        end

        module TableDefinition
          def remove_foreign_key(to_table = nil, **options)
            options[:_skip_column_match] = true
            super
          end
        end

        include RemoveForeignKeyColumnMatch

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end
      end

      class V7_2 < V8_0
      end

      class V7_1 < V7_2
      end

      class V7_0 < V7_1
        module LegacyIndexName
          private
            def legacy_index_name(table_name, options)
              if Hash === options
                if options[:column]
                  "index_#{table_name}_on_#{Array(options[:column]) * '_and_'}"
                elsif options[:name]
                  options[:name]
                else
                  raise ArgumentError, "You must specify the index name"
                end
              else
                legacy_index_name(table_name, index_name_options(options))
              end
            end

            def index_name_options(column_names)
              if expression_column_name?(column_names)
                column_names = column_names.scan(/\w+/).join("_")
              end

              { column: column_names }
            end

            def expression_column_name?(column_name)
              column_name.is_a?(String) && /\W/.match?(column_name)
            end
        end

        module TableDefinition
          include LegacyIndexName

          def column(name, type, **options)
            options[:_skip_validate_options] = true
            super
          end

          def change(name, type, **options)
            options[:_skip_validate_options] = true
            super
          end

          def index(column_name, **options)
            options[:name] = legacy_index_name(name, column_name) if options[:name].nil?
            super
          end

          def references(*args, **options)
            options[:_skip_validate_options] = true
            super
          end

          private
            def raise_on_if_exist_options(options)
            end
        end

        include LegacyIndexName

        def add_column(table_name, column_name, type, **options)
          options[:_skip_validate_options] = true
          super
        end

        def add_index(table_name, column_name, **options)
          options[:name] = legacy_index_name(table_name, column_name) if options[:name].nil?
          super
        end

        def add_reference(table_name, ref_name, **options)
          options[:_skip_validate_options] = true
          super
        end
        alias :add_belongs_to :add_reference

        def create_table(table_name, **options)
          options[:_uses_legacy_table_name] = true
          options[:_skip_validate_options] = true

          super
        end

        def rename_table(table_name, new_name, **options)
          options[:_uses_legacy_table_name] = true
          options[:_uses_legacy_index_name] = true
          super
        end

        def change_column(table_name, column_name, type, **options)
          options[:_skip_validate_options] = true
          super
        end

        def change_column_null(table_name, column_name, null, default = nil)
          super(table_name, column_name, !!null, default)
        end

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end
      end

      class V6_1 < V7_0
        def add_column(table_name, column_name, type, **options)
          if type == :datetime
            options[:precision] ||= nil
          end
          super
        end

        def change_column(table_name, column_name, type, **options)
          if type == :datetime
            options[:precision] ||= nil
          end
          super
        end

        module TableDefinition
          def change(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          private
            def raise_on_if_exist_options(options)
            end
        end

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end
      end

      class V6_0 < V6_1
        class ReferenceDefinition < ConnectionAdapters::ReferenceDefinition
          def index_options(table_name)
            as_options(index)
          end
        end

        module TableDefinition
          def references(*args, **options)
            options[:_uses_legacy_reference_index_name] = true
            super
          end
          alias :belongs_to :references

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          private
            def raise_on_if_exist_options(options)
            end
        end

        def add_reference(table_name, ref_name, **options)
          options[:_uses_legacy_reference_index_name] = true
          super
        end
        alias :add_belongs_to :add_reference

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end
      end

      class V5_2 < V6_0
        module TableDefinition
          def timestamps(**options)
            options[:precision] ||= nil
            super
          end

          def column(name, type, index: nil, **options)
            options[:precision] ||= nil
            super
          end

          private
            def raise_on_if_exist_options(options)
            end

            def raise_on_duplicate_column(name)
            end
        end

        module CommandRecorder
          def invert_transaction(args, &block)
            [:transaction, args, block]
          end

          def invert_change_column_comment(args)
            [:change_column_comment, args]
          end

          def invert_change_table_comment(args)
            [:change_table_comment, args]
          end
        end

        def add_timestamps(table_name, **options)
          options[:precision] ||= nil
          super
        end

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end

          def command_recorder
            recorder = super
            recorder.singleton_class.prepend(CommandRecorder)
            recorder
          end
      end

      class V5_1 < V5_2
      end

      class V5_0 < V5_1
        module TableDefinition
          def primary_key(name, type = :primary_key, **options)
            type = :integer if type == :primary_key
            super
          end

          def references(*args, **options)
            super(*args, type: :integer, **options)
          end
          alias :belongs_to :references

          private
            def raise_on_if_exist_options(options)
            end
        end

        def create_table(table_name, **options)
          # Check before setting the default :id so that migrations without an
          # explicit primary key type do not accidentally get default: nil applied
          # (the nil-default only applies when id: :integer or id: :bigint is
          # explicitly stated).
          unless options.delete(:_skip_pk_nil_default)
            if [:integer, :bigint].include?(options[:id]) && !options.key?(:default)
              options[:default] = nil
            end
          end

          # Since 5.1 PostgreSQL adapter uses bigserial type for primary
          # keys by default and MySQL uses bigint. This compat layer makes old migrations utilize
          # serial/int type instead -- the way it used to work before 5.1.
          unless options.key?(:id)
            options[:id] = :integer
          end

          super
        end

        def create_join_table(table_1, table_2, column_options: {}, **options)
          column_options.reverse_merge!(type: :integer)
          super
        end

        def add_column(table_name, column_name, type, **options)
          if type == :primary_key
            type = :integer
            options[:primary_key] = true
          elsif type == :datetime
            options[:precision] ||= nil
          end
          super
        end

        def add_reference(table_name, ref_name, **options)
          super(table_name, ref_name, type: :integer, **options)
        end
        alias :add_belongs_to :add_reference

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end
      end

      class V4_2 < V5_0
        module TableDefinition
          def references(*, **options)
            options[:index] ||= false
            super
          end
          alias :belongs_to :references

          def timestamps(**options)
            options[:null] = true if options[:null].nil?
            super
          end

          private
            def raise_on_if_exist_options(options)
            end
        end

        def add_reference(table_name, ref_name, **options)
          options[:index] ||= false
          super
        end
        alias :add_belongs_to :add_reference

        def add_timestamps(table_name, **options)
          options[:null] = true if options[:null].nil?
          super
        end

        def index_exists?(table_name, column_name = nil, **options)
          column_names = Array(column_name).map(&:to_s)
          options[:name] =
            if options[:name].present?
              options[:name].to_s
            else
              connection.index_name(table_name, column: column_names)
            end
          super
        end

        def remove_index(table_name, column_name = nil, **options)
          options[:name] = index_name_for_remove(table_name, column_name, options)
          super
        end

        private
          def compatible_table_definition(t)
            t.singleton_class.prepend(TableDefinition)
            super
          end

          def index_name_for_remove(table_name, column_name, options)
            index_name = connection.index_name(table_name, column_name || options)

            unless connection.index_name_exists?(table_name, index_name)
              if options.key?(:name)
                options_without_column = options.except(:column)
                index_name_without_column = connection.index_name(table_name, options_without_column)

                if connection.index_name_exists?(table_name, index_name_without_column)
                  return index_name_without_column
                end
              end

              raise ArgumentError, "Index name '#{index_name}' on table '#{table_name}' does not exist"
            end

            index_name
          end
      end
    end
  end
end

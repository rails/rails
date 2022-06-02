# frozen_string_literal: true

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :JoinBase
        autoload :JoinAssociation
      end

      class Aliases # :nodoc:
        def initialize(tables)
          @tables = tables
          @alias_cache = tables.each_with_object({}) { |table, h|
            h[table.node] = table.columns.each_with_object({}) { |column, i|
              i[column.name] = column.alias
            }
          }
          @columns_cache = tables.each_with_object({}) { |table, h|
            h[table.node] = table.columns
          }
        end

        def columns
          @tables.flat_map(&:column_aliases)
        end

        def column_aliases(node)
          @columns_cache[node]
        end

        def column_alias(node, column)
          @alias_cache[node][column]
        end

        Table = Struct.new(:node, :columns) do # :nodoc:
          def column_aliases
            t = node.table
            columns.map { |column| t[column.name].as(column.alias) }
          end
        end
        Column = Struct.new(:name, :alias)
      end

      def self.make_tree(associations)
        hash = {}
        walk_tree associations, hash
        hash
      end

      def self.walk_tree(associations, hash)
        case associations
        when Symbol, String
          hash[associations.to_sym] ||= {}
        when Array
          associations.each do |assoc|
            walk_tree assoc, hash
          end
        when Hash
          associations.each do |k, v|
            cache = hash[k] ||= {}
            walk_tree v, cache
          end
        else
          raise ConfigurationError, associations.inspect
        end
      end

      def initialize(base, table, associations, join_type)
        tree = self.class.make_tree associations
        @join_root = JoinBase.new(base, table, build(tree, base))
        @join_type = join_type
      end

      def base_klass
        join_root.base_klass
      end

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def join_constraints(joins_to_add, alias_tracker, references)
        @alias_tracker = alias_tracker
        @joined_tables = {}
        @references = {}

        references.each do |table_name|
          @references[table_name.to_sym] = table_name if table_name.is_a?(Arel::Nodes::SqlLiteral)
        end unless references.empty?

        joins = make_join_constraints(join_root, join_type)

        joins.concat joins_to_add.flat_map { |oj|
          if join_root.match? oj.join_root
            walk(join_root, oj.join_root, oj.join_type)
          else
            make_join_constraints(oj.join_root, oj.join_type)
          end
        }
      end

      def instantiate(result_set, strict_loading_value, &block)
        primary_key = aliases.column_alias(join_root, join_root.primary_key)

        seen = Hash.new { |i, parent|
          i[parent] = Hash.new { |j, child_class|
            j[child_class] = {}
          }
        }.compare_by_identity

        model_cache = Hash.new { |h, klass| h[klass] = {} }
        parents = model_cache[join_root]

        column_aliases = aliases.column_aliases(join_root)
        column_names = []

        result_set.columns.each do |name|
          column_names << name unless /\At\d+_r\d+\z/.match?(name)
        end

        if column_names.empty?
          column_types = {}
        else
          column_types = result_set.column_types
          unless column_types.empty?
            attribute_types = join_root.attribute_types
            column_types = column_types.slice(*column_names).delete_if { |k, _| attribute_types.key?(k) }
          end
          column_aliases += column_names.map! { |name| Aliases::Column.new(name, name) }
        end

        message_bus = ActiveSupport::Notifications.instrumenter

        payload = {
          record_count: result_set.length,
          class_name: join_root.base_klass.name
        }

        message_bus.instrument("instantiation.active_record", payload) do
          result_set.each { |row_hash|
            parent_key = primary_key ? row_hash[primary_key] : row_hash
            parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases, column_types, &block)
            construct(parent, join_root, row_hash, seen, model_cache, strict_loading_value)
          }
        end

        parents.values
      end

      def apply_column_aliases(relation)
        @join_root_alias = relation.select_values.empty?
        relation._select!(-> { aliases.columns })
      end

      def each(&block)
        join_root.each(&block)
      end

      protected
        attr_reader :join_root, :join_type

      private
        attr_reader :alias_tracker, :join_root_alias

        def aliases
          @aliases ||= Aliases.new join_root.each_with_index.map { |join_part, i|
            column_names = if join_part == join_root && !join_root_alias
              primary_key = join_root.primary_key
              primary_key ? [primary_key] : []
            else
              join_part.column_names
            end

            columns = column_names.each_with_index.map { |column_name, j|
              Aliases::Column.new column_name, "t#{i}_r#{j}"
            }
            Aliases::Table.new(join_part, columns)
          }
        end

        def make_join_constraints(join_root, join_type)
          join_root.children.flat_map do |child|
            make_constraints(join_root, child, join_type)
          end
        end

        def make_constraints(parent, child, join_type)
          foreign_table = parent.table
          foreign_klass = parent.base_klass
          child.join_constraints(foreign_table, foreign_klass, join_type, alias_tracker) do |reflection|
            table, terminated = @joined_tables[reflection]
            root = reflection == child.reflection

            if table && (!root || !terminated)
              @joined_tables[reflection] = [table, root] if root
              next table, true
            end

            table_name = @references[reflection.name.to_sym]&.to_s

            table = alias_tracker.aliased_table_for(reflection.klass.arel_table, table_name) do
              name = reflection.alias_candidate(parent.table_name)
              root ? name : "#{name}_join"
            end

            @joined_tables[reflection] ||= [table, root] if join_type == Arel::Nodes::OuterJoin
            table
          end.concat child.children.flat_map { |c| make_constraints(child, c, join_type) }
        end

        def walk(left, right, join_type)
          intersection, missing = right.children.map { |node1|
            [left.children.find { |node2| node1.match? node2 }, node1]
          }.partition(&:first)

          joins = intersection.flat_map { |l, r| r.table = l.table; walk(l, r, join_type) }
          joins.concat missing.flat_map { |_, n| make_constraints(left, n, join_type) }
        end

        def find_reflection(klass, name)
          klass._reflect_on_association(name) ||
            raise(ConfigurationError, "Can't join '#{klass.name}' to association named '#{name}'; perhaps you misspelled it?")
        end

        def build(associations, base_klass)
          associations.map do |name, right|
            reflection = find_reflection base_klass, name
            reflection.check_validity!
            reflection.check_eager_loadable!

            if reflection.polymorphic?
              raise EagerLoadPolymorphicError.new(reflection)
            end

            JoinAssociation.new(reflection, build(right, reflection.klass))
          end
        end

        def construct(ar_parent, parent, row, seen, model_cache, strict_loading_value)
          return if ar_parent.nil?

          parent.children.each do |node|
            if node.reflection.collection?
              other = ar_parent.association(node.reflection.name)
              other.loaded!
            elsif ar_parent.association_cached?(node.reflection.name)
              model = ar_parent.association(node.reflection.name).target
              construct(model, node, row, seen, model_cache, strict_loading_value)
              next
            end

            if node.primary_key
              key = aliases.column_alias(node, node.primary_key)
              id = row[key]
            else
              key = aliases.column_alias(node, node.reflection.join_primary_key.to_s)
              id = nil # Avoid id-based model caching.
            end

            if row[key].nil?
              nil_association = ar_parent.association(node.reflection.name)
              nil_association.loaded!
              next
            end

            unless model = seen[ar_parent][node][id]
              model = construct_model(ar_parent, node, row, model_cache, id, strict_loading_value)
              seen[ar_parent][node][id] = model if id
            end

            construct(model, node, row, seen, model_cache, strict_loading_value)
          end
        end

        def construct_model(record, node, row, model_cache, id, strict_loading_value)
          other = record.association(node.reflection.name)

          unless model = model_cache[node][id]
            model = node.instantiate(row, aliases.column_aliases(node)) do |m|
              m.strict_loading! if strict_loading_value
              other.set_inverse_instance(m)
            end
            model_cache[node][id] = model if id
          end

          if node.reflection.collection?
            other.target.push(model)
          else
            other.target = model
          end

          model.readonly! if node.readonly?
          model.strict_loading! if node.strict_loading?
          model
        end
    end
  end
end

# frozen_string_literal: true

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinBase,        "active_record/associations/join_dependency/join_base"
      autoload :JoinAssociation, "active_record/associations/join_dependency/join_association"

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
            columns.map { |column| t[column.name].as Arel.sql column.alias }
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

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def join_constraints(joins_to_add, alias_tracker)
        @alias_tracker = alias_tracker

        construct_tables!(join_root)
        joins = make_join_constraints(join_root, join_type)

        joins.concat joins_to_add.flat_map { |oj|
          construct_tables!(oj.join_root)
          if join_root.match? oj.join_root
            walk(join_root, oj.join_root, oj.join_type)
          else
            make_join_constraints(oj.join_root, oj.join_type)
          end
        }
      end

      def instantiate(result_set, &block)
        primary_key = aliases.column_alias(join_root, join_root.primary_key)

        seen = Hash.new { |i, object_id|
          i[object_id] = Hash.new { |j, child_class|
            j[child_class] = {}
          }
        }

        model_cache = Hash.new { |h, klass| h[klass] = {} }
        parents = model_cache[join_root]
        column_aliases = aliases.column_aliases join_root

        message_bus = ActiveSupport::Notifications.instrumenter

        payload = {
          record_count: result_set.length,
          class_name: join_root.base_klass.name
        }

        message_bus.instrument("instantiation.active_record", payload) do
          result_set.each { |row_hash|
            parent_key = primary_key ? row_hash[primary_key] : row_hash
            parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases, &block)
            construct(parent, join_root, row_hash, seen, model_cache)
          }
        end

        parents.values
      end

      def apply_column_aliases(relation)
        relation._select!(-> { aliases.columns })
      end

      protected
        attr_reader :join_root, :join_type

      private
        attr_reader :alias_tracker

        def aliases
          @aliases ||= Aliases.new join_root.each_with_index.map { |join_part, i|
            columns = join_part.column_names.each_with_index.map { |column_name, j|
              Aliases::Column.new column_name, "t#{i}_r#{j}"
            }
            Aliases::Table.new(join_part, columns)
          }
        end

        def construct_tables!(join_root)
          join_root.each_children do |parent, child|
            child.tables = table_aliases_for(parent, child)
          end
        end

        def make_join_constraints(join_root, join_type)
          join_root.children.flat_map do |child|
            make_constraints(join_root, child, join_type)
          end
        end

        def make_constraints(parent, child, join_type)
          foreign_table = parent.table
          foreign_klass = parent.base_klass
          joins = child.join_constraints(foreign_table, foreign_klass, join_type, alias_tracker)
          joins.concat child.children.flat_map { |c| make_constraints(child, c, join_type) }
        end

        def table_aliases_for(parent, node)
          node.reflection.chain.map { |reflection|
            alias_tracker.aliased_table_for(
              reflection.table_name,
              table_alias_for(reflection, parent, reflection != node.reflection),
              reflection.klass.type_caster
            )
          }
        end

        def table_alias_for(reflection, parent, join)
          name = reflection.alias_candidate(parent.table_name)
          join ? "#{name}_join" : name
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

        def construct(ar_parent, parent, row, seen, model_cache)
          return if ar_parent.nil?

          parent.children.each do |node|
            if node.reflection.collection?
              other = ar_parent.association(node.reflection.name)
              other.loaded!
            elsif ar_parent.association_cached?(node.reflection.name)
              model = ar_parent.association(node.reflection.name).target
              construct(model, node, row, seen, model_cache)
              next
            end

            key = aliases.column_alias(node, node.primary_key)
            id = row[key]
            if id.nil?
              nil_association = ar_parent.association(node.reflection.name)
              nil_association.loaded!
              next
            end

            model = seen[ar_parent.object_id][node][id]

            if model
              construct(model, node, row, seen, model_cache)
            else
              model = construct_model(ar_parent, node, row, model_cache, id)

              seen[ar_parent.object_id][node][id] = model
              construct(model, node, row, seen, model_cache)
            end
          end
        end

        def construct_model(record, node, row, model_cache, id)
          other = record.association(node.reflection.name)

          model = model_cache[node][id] ||=
            node.instantiate(row, aliases.column_aliases(node)) do |m|
              other.set_inverse_instance(m)
            end

          if node.reflection.collection?
            other.target.push(model)
          else
            other.target = model
          end

          model.readonly! if node.readonly?
          model
        end
    end
  end
end

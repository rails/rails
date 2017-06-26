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
          @name_and_alias_cache = tables.each_with_object({}) { |table, h|
            h[table.node] = table.columns.map { |column|
              [column.name, column.alias]
            }
          }
        end

        def columns
          @tables.flat_map(&:column_aliases)
        end

        # An array of [column_name, alias] pairs for the table
        def column_aliases(node)
          @name_and_alias_cache[node]
        end

        def column_alias(node, column)
          @alias_cache[node][column]
        end

        Table = Struct.new(:node, :columns) do # :nodoc:
          def table
            Arel::Nodes::TableAlias.new node.table, node.aliased_table_name
          end

          def column_aliases
            t = table
            columns.map { |column| t[column.name].as Arel.sql column.alias }
          end
        end
        Column = Struct.new(:name, :alias)
      end

      attr_reader :alias_tracker, :base_klass, :join_root

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

      # base is the base class on which operation is taking place.
      # associations is the list of associations which are joined using hash, symbol or array.
      # joins is the list of all string join commands and arel nodes.
      #
      #  Example :
      #
      #  class Physician < ActiveRecord::Base
      #    has_many :appointments
      #    has_many :patients, through: :appointments
      #  end
      #
      #  If I execute `@physician.patients.to_a` then
      #    base # => Physician
      #    associations # => []
      #    joins # =>  [#<Arel::Nodes::InnerJoin: ...]
      #
      #  However if I execute `Physician.joins(:appointments).to_a` then
      #    base # => Physician
      #    associations # => [:appointments]
      #    joins # =>  []
      #
      def initialize(base, associations, joins, eager_loading: true)
        @alias_tracker = AliasTracker.create_with_joins(base.connection, base.table_name, joins)
        @eager_loading = eager_loading
        tree = self.class.make_tree associations
        @join_root = JoinBase.new base, build(tree, base)
        @join_root.children.each { |child| construct_tables! @join_root, child }
      end

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def join_constraints(outer_joins, join_type)
        joins = join_root.children.flat_map { |child|

          if join_type == Arel::Nodes::OuterJoin
            make_left_outer_joins join_root, child
          else
            make_inner_joins join_root, child
          end
        }

        joins.concat outer_joins.flat_map { |oj|
          if join_root.match? oj.join_root
            walk join_root, oj.join_root
          else
            oj.join_root.children.flat_map { |child|
              make_outer_joins oj.join_root, child
            }
          end
        }
      end

      def aliases
        Aliases.new join_root.each_with_index.map { |join_part, i|
          columns = join_part.column_names.each_with_index.map { |column_name, j|
            Aliases::Column.new column_name, "t#{i}_r#{j}"
          }
          Aliases::Table.new(join_part, columns)
        }
      end

      def instantiate(result_set, aliases)
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
            parent = parents[parent_key] ||= join_root.instantiate(row_hash, column_aliases)
            construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
          }
        end

        parents.values
      end

      private

        def make_constraints(parent, child, tables, join_type)
          chain         = child.reflection.chain
          foreign_table = parent.table
          foreign_klass = parent.base_klass
          child.join_constraints(foreign_table, foreign_klass, join_type, tables, chain)
        end

        def make_outer_joins(parent, child)
          tables    = table_aliases_for(parent, child)
          join_type = Arel::Nodes::OuterJoin
          info      = make_constraints parent, child, tables, join_type

          [info] + child.children.flat_map { |c| make_outer_joins(child, c) }
        end

        def make_left_outer_joins(parent, child)
          tables    = child.tables
          join_type = Arel::Nodes::OuterJoin
          info      = make_constraints parent, child, tables, join_type

          [info] + child.children.flat_map { |c| make_left_outer_joins(child, c) }
        end

        def make_inner_joins(parent, child)
          tables    = child.tables
          join_type = Arel::Nodes::InnerJoin
          info      = make_constraints parent, child, tables, join_type

          [info] + child.children.flat_map { |c| make_inner_joins(child, c) }
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

        def construct_tables!(parent, node)
          node.tables = table_aliases_for(parent, node)
          node.children.each { |child| construct_tables! node, child }
        end

        def table_alias_for(reflection, parent, join)
          name = "#{reflection.plural_name}_#{parent.table_name}"
          name << "_join" if join
          name
        end

        def walk(left, right)
          intersection, missing = right.children.map { |node1|
            [left.children.find { |node2| node1.match? node2 }, node1]
          }.partition(&:first)

          ojs = missing.flat_map { |_, n| make_outer_joins left, n }
          intersection.flat_map { |l, r| walk l, r }.concat ojs
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
              next unless @eager_loading
              raise EagerLoadPolymorphicError.new(reflection)
            end

            JoinAssociation.new reflection, build(right, reflection.klass)
          end.compact
        end

        def construct(ar_parent, parent, row, rs, seen, model_cache, aliases)
          return if ar_parent.nil?

          parent.children.each do |node|
            if node.reflection.collection?
              other = ar_parent.association(node.reflection.name)
              other.loaded!
            elsif ar_parent.association_cached?(node.reflection.name)
              model = ar_parent.association(node.reflection.name).target
              construct(model, node, row, rs, seen, model_cache, aliases)
              next
            end

            key = aliases.column_alias(node, node.primary_key)
            id = row[key]
            if id.nil?
              nil_association = ar_parent.association(node.reflection.name)
              nil_association.loaded!
              next
            end

            model = seen[ar_parent.object_id][node.base_klass][id]

            if model
              construct(model, node, row, rs, seen, model_cache, aliases)
            else
              model = construct_model(ar_parent, node, row, model_cache, id, aliases)

              if node.reflection.scope_for(node.base_klass).readonly_value
                model.readonly!
              end

              seen[ar_parent.object_id][node.base_klass][id] = model
              construct(model, node, row, rs, seen, model_cache, aliases)
            end
          end
        end

        def construct_model(record, node, row, model_cache, id, aliases)
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

          model
        end
    end
  end
end

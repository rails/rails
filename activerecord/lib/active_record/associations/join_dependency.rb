module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinBase,        'active_record/associations/join_dependency/join_base'
      autoload :JoinAssociation, 'active_record/associations/join_dependency/join_association'

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
          associations.each do |k,v|
            cache = hash[k] ||= {}
            walk_tree v, cache
          end
        else
          raise ConfigurationError, associations.inspect
        end
      end

      # base is the base class on which operation is taking place.
      # associations is the list of associations which are joined using hash, symbol or array.
      # joins is the list of all string join commnads and arel nodes.
      #
      #  Example :
      #
      #  class Physician < ActiveRecord::Base
      #    has_many :appointments
      #    has_many :patients, through: :appointments
      #  end
      #
      #  If I execute `@physician.patients.to_a` then
      #    base #=> Physician
      #    associations #=> []
      #    joins #=>  [#<Arel::Nodes::InnerJoin: ...]
      #
      #  However if I execute `Physician.joins(:appointments).to_a` then
      #    base #=> Physician
      #    associations #=> [:appointments]
      #    joins #=>  []
      #
      def initialize(base, associations, joins)
        @base_klass    = base
        @join_root    = JoinBase.new(base)
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        tree = self.class.make_tree associations
        build tree, @join_root, Arel::InnerJoin
        apply_tables! @join_root
      end

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def merge_outer_joins!(other)
        left  = join_root
        right = other.join_root

        if left.match? right
          merge_node left, right
        else
          # If the roots aren't the same, then deep copy the RHS to the LHS
          left.children.concat right.children.map { |node|
            deep_copy left, node
          }
        end
        apply_tables! @join_root
      end

      def apply_tables!(node)
        node.children.each { |child| construct_tables! node, child }
      end

      def join_constraints(outer_joins)
        outer_joins.each { |oj| merge_outer_joins! oj }
        make_joins join_root
      end

      class Aliases
        def initialize(tables)
          @tables = tables
          @alias_cache = tables.each_with_object({}) { |table,h|
            h[table.node] = table.columns.each_with_object({}) { |column,i|
              i[column.name] = column.alias
            }
          }
          @name_and_alias_cache = tables.each_with_object({}) { |table,h|
            h[table.node] = table.columns.map { |column|
              [column.name, column.alias]
            }
          }
        end

        def columns
          @tables.flat_map { |t| t.column_aliases }
        end

        # An array of [column_name, alias] pairs for the table
        def column_aliases(node)
          @name_and_alias_cache[node]
        end

        def column_alias(node, column)
          @alias_cache[node][column]
        end

        class Table < Struct.new(:node, :columns)
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

      def aliases
        Aliases.new join_root.each_with_index.map { |join_part,i|
          columns = join_part.column_names.each_with_index.map { |column_name,j|
            Aliases::Column.new column_name, "t#{i}_r#{j}"
          }
          Aliases::Table.new(join_part, columns)
        }
      end

      def instantiate(result_set, aliases)
        primary_key = aliases.column_alias(join_root, join_root.primary_key)
        type_caster = result_set.column_type primary_key

        seen = Hash.new { |h,parent_klass|
          h[parent_klass] = Hash.new { |i,parent_id|
            i[parent_id] = Hash.new { |j,child_klass| j[child_klass] = {} }
          }
        }

        model_cache = Hash.new { |h,klass| h[klass] = {} }
        parents = model_cache[join_root]
        column_aliases = aliases.column_aliases join_root

        result_set.each { |row_hash|
          primary_id = type_caster.type_cast row_hash[primary_key]
          parent = parents[primary_id] ||= join_root.instantiate(row_hash, column_aliases)
          construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
        }

        parents.values
      end

      private

      def make_joins(node)
        node.children.flat_map { |child|
          chain = child.reflection.chain
          foreign_table = node.table
          foreign_klass = node.base_klass
          child.join_constraints(foreign_table, foreign_klass, child, child.join_type, child.tables, child.reflection.scope_chain, chain)
            .concat make_joins(child)
        }
      end

      def construct_tables!(parent, node)
        node.tables = node.reflection.chain.map { |reflection|
          alias_tracker.aliased_table_for(
            reflection.table_name,
            table_alias_for(reflection, parent, reflection != node.reflection)
          )
        } unless node.tables
        node.children.each { |child| construct_tables! node, child }
      end

      def table_alias_for(reflection, parent, join)
        name = "#{reflection.plural_name}_#{parent.table_name}"
        name << "_join" if join
        name
      end

      def merge_node(left, right)
        intersection, missing = right.children.map { |node1|
          [left.children.find { |node2| node1.match? node2 }, node1]
        }.partition(&:first)

        intersection.each { |l,r| merge_node l, r }

        left.children.concat missing.map { |_,node| deep_copy left, node }
      end

      def deep_copy(parent, node)
        dup = build_join_association(node.reflection, parent, Arel::OuterJoin)
        dup.children.concat node.children.map { |n| deep_copy dup, n }
        dup
      end

      def find_reflection(klass, name)
        klass.reflect_on_association(name) or
          raise ConfigurationError, "Association named '#{ name }' was not found on #{ klass.name }; perhaps you misspelled it?"
      end

      def build(associations, parent, join_type)
        associations.each do |name, right|
          reflection = find_reflection parent.base_klass, name
          join_association = build_join_association reflection, parent, join_type
          parent.children << join_association
          build right, join_association, join_type
        end
      end

      def build_join_association(reflection, parent, join_type)
        reflection.check_validity!

        if reflection.options[:polymorphic]
          raise EagerLoadPolymorphicError.new(reflection)
        end

        node = JoinAssociation.new(reflection, join_type)
        node
      end

      def construct(ar_parent, parent, row, rs, seen, model_cache, aliases)
        primary_id  = ar_parent.id

        parent.children.each do |node|
          if node.reflection.collection?
            other = ar_parent.association(node.reflection.name)
            other.loaded!
          else
            if ar_parent.association_cache.key?(node.reflection.name)
              model = ar_parent.association(node.reflection.name).target
              construct(model, node, row, rs, seen, model_cache, aliases)
              next
            end
          end

          key = aliases.column_alias(node, node.primary_key)
          id = row[key]
          next if id.nil?

          model = seen[parent.base_klass][primary_id][node.base_klass][id]

          if model
            construct(model, node, row, rs, seen, model_cache, aliases)
          else
            model = construct_model(ar_parent, node, row, model_cache, id, aliases)
            seen[parent.base_klass][primary_id][node.base_klass][id] = model
            construct(model, node, row, rs, seen, model_cache, aliases)
          end
        end
      end

      def construct_model(record, node, row, model_cache, id, aliases)
        model = model_cache[node][id] ||= node.instantiate(row,
                                                           aliases.column_aliases(node))
        other = record.association(node.reflection.name)

        if node.reflection.collection?
          other.target.push(model)
        else
          other.target = model
        end

        other.set_inverse_instance(model)
        model
      end
    end
  end
end

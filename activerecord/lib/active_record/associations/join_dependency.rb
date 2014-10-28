module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinBase,        'active_record/associations/join_dependency/join_base'
      autoload :JoinAssociation, 'active_record/associations/join_dependency/join_association'

      class Aliases # :nodoc:
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

      class Tree # :nodoc:
        def initialize(associations = nil)
          @tree = {}
          add_associations(associations) if associations
        end

        def add_associations(associations)
          walk(associations, @tree)
        end

        def map(&block)
          @tree.map(&block)
        end

        private
        def walk(associations, hash, strict = true) # recursion is always strict
          case associations
          when Symbol, String
            hash[associations.to_sym] ||= {}
          when Array
            associations.each do |assoc|
              walk assoc, hash
            end
          when Hash
            associations.each do |k,v|
              cache = hash[k] ||= {}
              walk v, cache
            end
          else
            raise ConfigurationError, associations.inspect if strict
          end
        end

        def self.to_tree(associations = nil)
          associations.kind_of?(self) ? associations : new(associations)
        end
      end
      
      # Same as Tree, except it accepts associations only if these are valid
      # AR association joins() params (ie: :books, {:author => :book}, but not
      # 'JOINS books' or Arel::Nodes::Join objects).
      class JoinsTree < Tree # :nodoc:
        def association_join_param?(assocs)
          # note that association joins() param can't be a String (strings passed to
          # joins() must be literal/valid raw SQL joins), contrast this with Tree
          # being able to walk() Strings (this is because Strings are valid includes(),
          # references() params)
          assocs.kind_of?(Symbol) || assocs.kind_of?(Hash) || assocs.kind_of?(Array)
        end

        def add_associations(assocs)
          if association_join_param?(assocs)
            super
            true
          else
            false
          end
        end

        def drain_associations_as_join_dependency_param(associations_param)
          join_dependency_param = nil
          drain(associations_param) do |associations_name, subtree, multiple_values_incoming|
            if multiple_values_incoming
              (join_dependency_param ||= {})[associations_name] = subtree
            elsif subtree.empty?
              join_dependency_param = associations_name # no need for Hash, can avoid allocation
            else
              join_dependency_param = {associations_name => subtree}
            end
          end
          join_dependency_param
        end

        def drain_associations_as_join_infos(join_dependency, associations_param)
          join_infos = nil
          drain(associations_param) do |association_name, subtree, multiple_values_incoming|
            join_infos ||= []
            join_infos.concat(join_dependency.make_association_inner_join(association_name))
          end
          join_infos
        end

        private
        def drain(associations_param)
          case associations_param
          when Symbol
            if subtree = @tree.delete(associations_param)
              yield associations_param, subtree, false
            end
          when Hash, Array
            associations_param.public_send(associations_param.kind_of?(Hash) ? :each_key : :each) do |association_name|
              if subtree = @tree.delete(association_name)
                yield association_name, subtree, true
              end
            end
          end
        end
      end

      attr_reader :alias_tracker, :base_klass, :join_root

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
      def initialize(base, associations, joins = [])
        @alias_tracker = AliasTracker.create(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name, base.table_name) # Updates the count for base.table_name to 1
        # associations Hash can be used directly, no need to explicitly convert it into Tree
        tree = associations.kind_of?(Hash) ? associations : Tree.to_tree(associations)
        @join_root = JoinBase.new base, build(tree, base)
        @join_root.children.each { |child| construct_tables! @join_root, child }
      end

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def join_constraints_for_join_dependency(join)
        if join_root.match? join.join_root
          walk join_root, join.join_root
        else
          join.join_root.children.flat_map { |child|
            make_outer_joins join.join_root, child
          }
        end
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

        seen = Hash.new { |h,parent_klass|
          h[parent_klass] = Hash.new { |i,parent_id|
            i[parent_id] = Hash.new { |j,child_klass| j[child_klass] = {} }
          }
        }

        model_cache = Hash.new { |h,klass| h[klass] = {} }
        parents = model_cache[join_root]
        column_aliases = aliases.column_aliases join_root

        message_bus = ActiveSupport::Notifications.instrumenter

        payload = {
          record_count: result_set.length,
          class_name: join_root.base_klass.name
        }

        message_bus.instrument('instantiation.active_record', payload) do
          result_set.each { |row_hash|
            parent = parents[row_hash[primary_key]] ||= join_root.instantiate(row_hash, column_aliases)
            construct(parent, join_root, row_hash, result_set, seen, model_cache, aliases)
          }
        end

        parents.values
      end

      def make_association_inner_join(association_name)
        join_root.children.each do |child|
          return make_inner_joins(join_root, child) if child.reflection.name == association_name
        end
        nil
      end

      private

      def make_constraints(parent, child, tables, join_type)
        chain         = child.reflection.chain
        foreign_table = parent.table
        foreign_klass = parent.base_klass
        child.join_constraints(foreign_table, foreign_klass, child, join_type, tables, child.reflection.scope_chain, chain)
      end

      def make_outer_joins(parent, child)
        tables    = table_aliases_for(parent, child)
        join_type = Arel::Nodes::OuterJoin
        info      = make_constraints parent, child, tables, join_type

        [info] + child.children.flat_map { |c| make_outer_joins(child, c) }
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
            table_alias_for(reflection, parent, reflection != node.reflection)
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

        ojs = missing.flat_map { |_,n| make_outer_joins left, n }
        intersection.flat_map { |l,r| walk l, r }.concat ojs
      end

      def find_reflection(klass, name)
        klass._reflect_on_association(name) or
          raise ConfigurationError, "Association named '#{ name }' was not found on #{ klass.name }; perhaps you misspelled it?"
      end

      def build(associations, base_klass)
        associations.map do |name, right|
          reflection = find_reflection base_klass, name
          reflection.check_validity!
          reflection.check_eager_loadable!

          if reflection.polymorphic?
            raise EagerLoadPolymorphicError.new(reflection)
          end

          JoinAssociation.new reflection, build(right, reflection.klass)
        end
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

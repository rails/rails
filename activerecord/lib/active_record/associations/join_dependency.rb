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
      end

      def join_constraints
        make_joins join_root
      end

      def columns
        join_root.collect { |join_part|
          table = join_part.aliased_table
          join_part.column_names_with_alias.collect{ |column_name, aliased_name|
            table[column_name].as Arel.sql(aliased_name)
          }
        }.flatten
      end

      def instantiate(result_set)
        primary_key = join_root.aliased_primary_key
        parents = {}

        type_caster = result_set.column_type primary_key

        records = result_set.map { |row_hash|
          primary_id = type_caster.type_cast row_hash[primary_key]
          parent = parents[primary_id] ||= join_root.instantiate(row_hash)
          construct(parent, join_root, row_hash, result_set)
          parent
        }.uniq

        remove_duplicate_results!(base_klass, records, join_root.children)
        records
      end

      private

      def make_joins(node)
        node.children.flat_map { |child|
          child.join_constraints(node).concat make_joins(child)
        }
      end

      def construct_tables!(parent, node)
        node.tables = node.reflection.chain.map { |reflection|
          alias_tracker.aliased_table_for(
            reflection.table_name,
            table_alias_for(reflection, parent, reflection != node.reflection)
          )
        }.reverse
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

      def remove_duplicate_results!(base, records, associations)
        associations.each do |node|
          reflection = node.reflection
          remove_uniq_by_reflection(reflection, records)

          parent_records = []
          records.each do |record|
            if descendant = record.send(reflection.name)
              if reflection.collection?
                parent_records.concat descendant.target.uniq
              else
                parent_records << descendant
              end
            end
          end

          unless parent_records.empty?
            remove_duplicate_results!(reflection.klass, parent_records, node.children)
          end
        end
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

      def build_scalar(reflection, parent, join_type)
        join_association = build_join_association(reflection, parent, join_type)
        parent.children << join_association
      end

      def remove_uniq_by_reflection(reflection, records)
        if reflection.collection?
          records.each { |record| record.send(reflection.name).target.uniq! }
        end
      end

      def build_join_association(reflection, parent, join_type)
        reflection.check_validity!

        if reflection.options[:polymorphic]
          raise EagerLoadPolymorphicError.new(reflection)
        end

        node = JoinAssociation.new(reflection, join_root.to_a.length, join_type)
        construct_tables!(parent, node)
        node
      end

      def construct(ar_parent, parent, row, rs)
        primary_key = parent.aliased_primary_key
        type_caster = rs.column_type primary_key

        parent.children.each do |node|
          primary_id = type_caster.type_cast row[primary_key]
          if ar_parent.id == primary_id
            if node.reflection.collection?
              other = ar_parent.association(node.reflection.name)
              other.loaded!
            end

            next if row[node.aliased_primary_key].nil?

            model = construct_model(ar_parent, node, row)
            construct(model, node, row, rs)
          end
        end
      end

      def construct_model(record, join_part, row)
        if join_part.reflection.collection?
          model = join_part.instantiate(row)
          other = record.association(join_part.reflection.name)
          other.target.push(model)
          other.set_inverse_instance(model)
        else
          return record.association(join_part.reflection.name).target if record.association_cache.key?(join_part.reflection.name)
          model = join_part.instantiate(row)
          other = record.association(join_part.reflection.name)
          other.target = model
          other.set_inverse_instance(model)
        end
        model
      end
    end
  end
end

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
        @table_joins   = joins
        @join_root    = JoinBase.new(base)
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        tree = self.class.make_tree associations
        build tree, @join_root, Arel::InnerJoin
      end

      def graft(*associations)
        associations.reject { |join_node|
          find_node join_node
        }.each { |join_node|
          parent     = find_node(join_node.parent) || join_root
          reflection = join_node.reflection
          type       = join_node.join_type

          next if parent.children.find { |j| j.reflection == reflection }
          build_scalar reflection, parent, type
        }
        self
      end

      def reflections
        join_root.drop(1).map!(&:reflection)
      end

      def join_relation(relation)
        join_root.inject(relation) do |rel,association|
          association.join_relation(rel)
        end
      end

      def join_constraints
        join_root.flat_map(&:join_constraints)
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
        assoc = join_root.children

        records = result_set.map { |row_hash|
          primary_id = type_caster.type_cast row_hash[primary_key]
          parent = parents[primary_id] ||= join_root.instantiate(row_hash)
          construct(parent, assoc, row_hash, result_set)
          parent
        }.uniq

        remove_duplicate_results!(base_klass, records, assoc)
        records
      end

      private

      def find_node(target_node)
        stack = target_node.parents << target_node

        left  = [join_root]
        right = stack.shift

        loop {
          match = left.find { |l| l.match? right }

          if match
            return match if stack.empty?

            left  = match.children
            right = stack.shift
          else
            return nil
          end
        }
      end

      def node_cmp(parent, join_part)
        return true if parent == join_part
        return unless parent.class == join_part.class

        case parent
        when JoinBase
          parent.base_klass == join_part.base_klass
        else
          parent.reflection == join_part.reflection &&
            node_cmp(parent.parent, join_part.parent)
        end
      end

      def remove_duplicate_results!(base, records, associations)
        associations.each do |node|
          reflection = base.reflect_on_association(node.name)
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
        if reflection && reflection.collection?
          records.each { |record| record.send(reflection.name).target.uniq! }
        end
      end

      def build_join_association(reflection, parent, join_type)
        reflection.check_validity!

        if reflection.options[:polymorphic]
          raise EagerLoadPolymorphicError.new(reflection)
        end

        JoinAssociation.new(reflection, join_root.to_a.length, parent, join_type, alias_tracker)
      end

      def construct(parent, nodes, row, rs)
        nodes.sort_by { |k| k.name }.each do |node|
          association = construct_association(parent, node, row, rs)
          construct(association, node.children, row, rs) if association
        end
      end

      def construct_association(record, join_part, row, rs)
        caster = rs.column_type(join_part.parent.aliased_primary_key)
        row_id = caster.type_cast row[join_part.parent.aliased_primary_key]

        return if record.id != row_id

        macro = join_part.reflection.macro
        if macro == :has_one
          return record.association(join_part.reflection.name).target if record.association_cache.key?(join_part.reflection.name)
          association = join_part.instantiate(row) unless row[join_part.aliased_primary_key].nil?
          set_target_and_inverse(join_part, association, record)
        else
          association = join_part.instantiate(row) unless row[join_part.aliased_primary_key].nil?
          case macro
          when :has_many
            other = record.association(join_part.reflection.name)
            other.loaded!
            other.target.push(association) if association
            other.set_inverse_instance(association)
          when :belongs_to
            set_target_and_inverse(join_part, association, record)
          else
            raise ConfigurationError, "unknown macro: #{join_part.reflection.macro}"
          end
        end
        association
      end

      def set_target_and_inverse(join_part, association, record)
        other = record.association(join_part.reflection.name)
        other.target = association
        other.set_inverse_instance(association)
      end
    end
  end
end

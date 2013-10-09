module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinBase,        'active_record/associations/join_dependency/join_base'
      autoload :JoinAssociation, 'active_record/associations/join_dependency/join_association'

      attr_reader :alias_tracker, :base_klass

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
        @join_parts    = Node.new JoinBase.new(base)
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        tree = self.class.make_tree associations
        build tree, @join_parts, Arel::InnerJoin
      end

      class Node # :nodoc:
        include Enumerable

        attr_reader :join_part, :children

        def initialize(join_part)
          @join_part = join_part
          @children  = []
        end

        def association_hash
          association_hash_iter children, {}
        end

        def each
          yield self
          iter = lambda { |list|
            list.each { |item|
              yield item
              iter.call item.children
            }
          }
          iter.call children
        end

        private
        def association_hash_iter nodes, acc
          nodes.each { |node|
            h = acc[node.join_part.reflection.name] ||= {}
            association_hash_iter node.children, h
          }
          acc
        end
      end

      def join_parts
        @join_parts.map(&:join_part)
      end

      def graft(*associations)
        join_assocs = join_associations

        associations.reject { |association|
          join_assocs.detect { |a| association == a }
        }.each { |association|
          join_node = find_parent_node(association.parent) || @join_parts
          type      = association.join_type
          find_or_build_scalar association.reflection, join_node, type
        }
        self
      end

      def join_associations
        join_parts.drop 1
      end

      def reflections
        join_associations.map(&:reflection)
      end

      def join_relation(relation)
        join_associations.inject(relation) do |rel,association|
          association.join_relation(rel)
        end
      end

      def columns
        join_parts.collect { |join_part|
          table = join_part.aliased_table
          join_part.column_names_with_alias.collect{ |column_name, aliased_name|
            table[column_name].as Arel.sql(aliased_name)
          }
        }.flatten
      end

      def instantiate(result_set)
        primary_key = join_base.aliased_primary_key
        parents = {}

        type_caster = result_set.column_type primary_key
        assoc = associations

        records = result_set.map { |row_hash|
          primary_id = type_caster.type_cast row_hash[primary_key]
          parent = parents[primary_id] ||= join_base.instantiate(row_hash)
          construct(parent, assoc, join_associations, row_hash, result_set)
          parent
        }.uniq

        remove_duplicate_results!(base_klass, records, assoc)
        records
      end

      private

      def associations
        @join_parts.association_hash
      end

      def find_parent_node(parent)
        @join_parts.find { |node|
          join_part = node.join_part
          case parent
          when JoinBase
            parent.base_klass == join_part.base_klass
          else
            parent == join_part
          end
        }
      end

      def join_base
        @join_parts.first.join_part
      end

      def remove_duplicate_results!(base, records, associations)
        associations.each_key do |name|
          reflection = base.reflect_on_association(name)
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
            remove_duplicate_results!(reflection.klass, parent_records, associations[name])
          end
        end
      end

      def find_reflection(klass, name)
        klass.reflect_on_association(name.intern) or
          raise ConfigurationError, "Association named '#{ name }' was not found on #{ klass.name }; perhaps you misspelled it?"
      end

      def build(associations, root, join_type)
        parent = root.join_part
        associations.each do |name, right|
          reflection = find_reflection parent.base_klass, name
          join_association = build_join_association reflection, parent, join_type
          root.children << join_association
          build right, join_association, join_type
        end
      end

      def find_or_build_scalar(reflection, node, join_type)
        parent = node.join_part
        unless join_association = find_join_association(reflection, node.join_part)
          join_association = build_join_association(reflection, parent, join_type)
          node.children << join_association
        end
        join_association
      end

      def find_join_association(reflection, parent)
        join_associations.detect { |j|
          j.reflection == reflection && j.parent == parent
        }
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

        part = JoinAssociation.new(reflection, join_parts.length, parent, join_type, alias_tracker)
        Node.new part
      end

      def construct(parent, associations, join_parts, row, rs)
        associations.sort_by { |k,_| k.to_s }.each do |association_name, assoc|
          association = construct_scalar(parent, association_name, join_parts, row, rs)
          construct(association, assoc, join_parts, row, rs) if association
        end
      end

      def construct_scalar(parent, associations, join_parts, row, rs)
        name = associations.to_s

        join_part = join_parts.detect { |j|
          j.reflection.name.to_s == name &&
            j.parent_table_name == parent.class.table_name
        }

        raise(ConfigurationError, "No such association") unless join_part

        join_parts.delete(join_part)
        construct_association(parent, join_part, row, rs)
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

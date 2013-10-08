module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinBase,        'active_record/associations/join_dependency/join_base'
      autoload :JoinAssociation, 'active_record/associations/join_dependency/join_association'

      attr_reader :join_parts, :reflections, :alias_tracker, :base_klass

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
        @join_parts    = [JoinBase.new(base)]
        @reflections   = []
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        tree = self.class.make_tree associations
        build tree, join_parts.last, Arel::InnerJoin
      end

      def graft(*associations)
        associations.each do |association|
          join_associations.detect { |a| association == a } ||
            find_or_build_scalar(association.reflection.name, find_parent_part(association.parent) || join_base, association.join_type)
        end
        self
      end

      def join_associations
        join_parts.drop 1
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
        join_associations.each_with_object({}) do |assoc, tree|
          cache_joined_association assoc, tree
        end
      end

      def find_parent_part(parent)
        join_parts.detect do |join_part|
          case parent
          when JoinBase
            parent.base_klass == join_part.base_klass
          else
            parent == join_part
          end
        end
      end

      def join_base
        join_parts.first
      end

      def remove_duplicate_results!(base, records, associations)
        case associations
        when Symbol, String
          reflection = base.reflections[associations]
          remove_uniq_by_reflection(reflection, records)
        when Hash
          associations.each_key do |name|
            reflection = base.reflections[name]
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

            remove_duplicate_results!(reflection.klass, parent_records, associations[name]) unless parent_records.empty?
          end
        end
      end

      def cache_joined_association(association, tree)
        associations = []
        parent = association.parent
        while parent != join_base
          associations.unshift(parent.reflection.name)
          parent = parent.parent
        end
        ref = associations.inject(tree) do |cache,key|
          cache[key]
        end
        ref[association.reflection.name] ||= {}
      end

      def find_reflection(klass, name)
        klass.reflect_on_association(name.intern) or
          raise ConfigurationError, "Association named '#{ name }' was not found on #{ klass.name }; perhaps you misspelled it?"
      end

      def build(associations, parent, join_type)
        associations.each do |left, right|
          join_association = find_or_build_scalar left, parent, join_type
          build right, join_association, join_type
        end
      end

      def find_or_build_scalar(name, parent, join_type)
        reflection = find_reflection parent.base_klass, name
        unless join_association = find_join_association(reflection, parent)
          @reflections << reflection
          join_association = build_join_association(reflection, parent, join_type)
          @join_parts << join_association
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

        JoinAssociation.new(reflection, join_parts.length, parent, join_type, alias_tracker)
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

module ActiveRecord
  module Associations
    class JoinDependency # :nodoc:
      autoload :JoinPart,        'active_record/associations/join_dependency/join_part'
      autoload :JoinBase,        'active_record/associations/join_dependency/join_base'
      autoload :JoinAssociation, 'active_record/associations/join_dependency/join_association'

      attr_reader :join_parts, :reflections, :alias_tracker, :active_record

      def initialize(base, associations, joins)
        @active_record = base
        @table_joins   = joins
        @join_parts    = [JoinBase.new(base)]
        @associations  = {}
        @reflections   = []
        @alias_tracker = AliasTracker.new(base.connection, joins)
        @alias_tracker.aliased_name_for(base.table_name) # Updates the count for base.table_name to 1
        build(associations)
      end

      def graft(*associations)
        associations.each do |association|
          join_associations.detect {|a| association == a} ||
            build(association.reflection.name, association.find_parent_in(self) || join_base, association.join_type)
        end
        self
      end

      def join_associations
        join_parts.last(join_parts.length - 1)
      end

      def join_base
        join_parts.first
      end

      def columns
        join_parts.collect { |join_part|
          table = join_part.aliased_table
          join_part.column_names_with_alias.collect{ |column_name, aliased_name|
            table[column_name].as Arel.sql(aliased_name)
          }
        }.flatten
      end

      def instantiate(rows)
        primary_key = join_base.aliased_primary_key
        parents = {}

        records = rows.map { |model|
          primary_id = model[primary_key]
          parent = parents[primary_id] ||= join_base.instantiate(model)
          construct(parent, @associations, join_associations, model)
          parent
        }.uniq

        remove_duplicate_results!(active_record, records, @associations)
        records
      end

      def remove_duplicate_results!(base, records, associations)
        case associations
        when Symbol, String
          reflection = base.reflections[associations]
          remove_uniq_by_reflection(reflection, records)
        when Array
          associations.each do |association|
            remove_duplicate_results!(base, records, association)
          end
        when Hash
          associations.keys.each do |name|
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

      protected

      def cache_joined_association(association)
        associations = []
        parent = association.parent
        while parent != join_base
          associations.unshift(parent.reflection.name)
          parent = parent.parent
        end
        ref = @associations
        associations.each do |key|
          ref = ref[key]
        end
        ref[association.reflection.name] ||= {}
      end

      def build(associations, parent = nil, join_type = Arel::InnerJoin)
        parent ||= join_parts.last
        case associations
        when Symbol, String
          reflection = parent.reflections[associations.to_s.intern] or
          raise ConfigurationError, "Association named '#{ associations }' was not found on #{parent.active_record.name}; perhaps you misspelled it?"
          unless join_association = find_join_association(reflection, parent)
            @reflections << reflection
            join_association = build_join_association(reflection, parent)
            join_association.join_type = join_type
            @join_parts << join_association
            cache_joined_association(join_association)
          end
          join_association
        when Array
          associations.each do |association|
            build(association, parent, join_type)
          end
        when Hash
          associations.keys.sort_by { |a| a.to_s }.each do |name|
            join_association = build(name, parent, join_type)
            build(associations[name], join_association, join_type)
          end
        else
          raise ConfigurationError, associations.inspect
        end
      end

      def find_join_association(name_or_reflection, parent)
        if String === name_or_reflection
          name_or_reflection = name_or_reflection.to_sym
        end

        join_associations.detect { |j|
          j.reflection == name_or_reflection && j.parent == parent
        }
      end

      def remove_uniq_by_reflection(reflection, records)
        if reflection && reflection.collection?
          records.each { |record| record.send(reflection.name).target.uniq! }
        end
      end

      def build_join_association(reflection, parent)
        JoinAssociation.new(reflection, self, parent)
      end

      def construct(parent, associations, join_parts, row)
        case associations
        when Symbol, String
          name = associations.to_s

          join_part = join_parts.detect { |j|
            j.reflection.name.to_s == name &&
              j.parent_table_name == parent.class.table_name }

            raise(ConfigurationError, "No such association") unless join_part

            join_parts.delete(join_part)
            construct_association(parent, join_part, row)
        when Array
          associations.each do |association|
            construct(parent, association, join_parts, row)
          end
        when Hash
          associations.sort_by { |k,_| k.to_s }.each do |association_name, assoc|
            association = construct(parent, association_name, join_parts, row)
            construct(association, assoc, join_parts, row) if association
          end
        else
          raise ConfigurationError, associations.inspect
        end
      end

      def construct_association(record, join_part, row)
        return if record.id.to_s != join_part.parent.record_id(row).to_s

        macro = join_part.reflection.macro
        if macro == :has_one
          return record.association(join_part.reflection.name).target if record.association_cache.key?(join_part.reflection.name)
          association = join_part.instantiate(row) unless row[join_part.aliased_primary_key].nil?
          set_target_and_inverse(join_part, association, record)
        else
          association = join_part.instantiate(row) unless row[join_part.aliased_primary_key].nil?
          case macro
          when :has_many, :has_and_belongs_to_many
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

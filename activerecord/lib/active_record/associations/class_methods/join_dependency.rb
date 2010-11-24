require 'active_record/associations/class_methods/join_dependency/join_part'
require 'active_record/associations/class_methods/join_dependency/join_base'
require 'active_record/associations/class_methods/join_dependency/join_association'

module ActiveRecord
  module Associations
    module ClassMethods
      class JoinDependency # :nodoc:
        attr_reader :join_parts, :reflections, :table_aliases

        def initialize(base, associations, joins)
          @join_parts            = [JoinBase.new(base, joins)]
          @associations          = {}
          @reflections           = []
          @table_aliases         = Hash.new(0)
          @table_aliases[base.table_name] = 1
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

        def columns(connection)
          join_parts.collect { |join_part|
            join_part.column_names_with_alias.collect{ |column_name, aliased_name|
              "#{connection.quote_table_name join_part.aliased_table_name}.#{connection.quote_column_name column_name} AS #{aliased_name}"
            }
          }.flatten.join(", ")
        end

        def count_aliases_from_table_joins(name)
          # quoted_name should be downcased as some database adapters (Oracle) return quoted name in uppercase
          quoted_name = join_base.active_record.connection.quote_table_name(name.downcase).downcase
          join_sql = join_base.table_joins.to_s.downcase
          join_sql.blank? ? 0 :
            # Table names
            join_sql.scan(/join(?:\s+\w+)?\s+#{quoted_name}\son/).size +
            # Table aliases
            join_sql.scan(/join(?:\s+\w+)?\s+\S+\s+#{quoted_name}\son/).size
        end

        def instantiate(rows)
          primary_key = join_base.aliased_primary_key
          parents = {}

          records = rows.map { |model|
            primary_id = model[primary_key]
            parent = parents[primary_id] ||= join_base.instantiate(model)
            construct(parent, @associations, join_associations.dup, model)
            parent
          }.uniq

          remove_duplicate_results!(join_base.active_record, records, @associations)
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
            raise ConfigurationError, "Association named '#{ associations }' was not found; perhaps you misspelled it?"
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
            associations.keys.sort{|a,b|a.to_s<=>b.to_s}.each do |name|
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
                j.parent_table_name    == parent.class.table_name }

              raise(ConfigurationError, "No such association") unless join_part

              join_parts.delete(join_part)
              construct_association(parent, join_part, row)
          when Array
            associations.each do |association|
              construct(parent, association, join_parts, row)
            end
          when Hash
            associations.sort_by { |k,_| k.to_s }.each do |name, assoc|
              association = construct(parent, name, join_parts, row)
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
            return if record.instance_variable_defined?("@#{join_part.reflection.name}")
            association = join_part.instantiate(row) unless row[join_part.aliased_primary_key].nil?
            set_target_and_inverse(join_part, association, record)
          else
            return if row[join_part.aliased_primary_key].nil?
            association = join_part.instantiate(row)
            case macro
            when :has_many, :has_and_belongs_to_many
              collection = record.send(join_part.reflection.name)
              collection.loaded
              collection.target.push(association)
              collection.__send__(:set_inverse_instance, association, record)
            when :belongs_to
              set_target_and_inverse(join_part, association, record)
            else
              raise ConfigurationError, "unknown macro: #{join_part.reflection.macro}"
            end
          end
          association
        end

        def set_target_and_inverse(join_part, association, record)
          association_proxy = record.send("set_#{join_part.reflection.name}_target", association)
          association_proxy.__send__(:set_inverse_instance, association, record)
        end
      end
    end
  end
end

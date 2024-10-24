# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Branch # :nodoc:
        attr_reader :association, :children, :parent
        attr_reader :scope, :associate_by_default
        attr_writer :preloaded_records

        def initialize(association:, children:, parent:, associate_by_default:, scope:, load_columns: {})
          @association = if association
            begin
              @association = association.to_sym
            rescue NoMethodError
              raise ArgumentError, "Association names must be Symbol or String, got: #{association.class.name}"
            end
          end
          @parent = parent
          @scope = scope
          @associate_by_default = associate_by_default
          @load_columns = load_columns
          @children = build_children(children)
          @loaders = nil
        end

        def future_classes
          (immediate_future_classes + children.flat_map(&:future_classes)).uniq
        end

        def immediate_future_classes
          if parent.done?
            loaders.flat_map(&:future_classes).uniq
          else
            likely_reflections.reject(&:polymorphic?).flat_map do |reflection|
              reflection.
                chain.
                map(&:klass)
            end.uniq
          end
        end

        def target_classes
          if done?
            preloaded_records.map(&:klass).uniq
          elsif parent.done?
            loaders.map(&:klass).uniq
          else
            likely_reflections.reject(&:polymorphic?).map(&:klass).uniq
          end
        end

        def likely_reflections
          parent_classes = parent.target_classes
          parent_classes.filter_map do |parent_klass|
            parent_klass._reflect_on_association(@association)
          end
        end

        def root?
          parent.nil?
        end

        def source_records
          @parent.preloaded_records
        end

        def preloaded_records
          @preloaded_records ||= loaders.flat_map(&:preloaded_records)
        end

        def done?
          root? || (@loaders && @loaders.all?(&:run?))
        end

        def runnable_loaders
          loaders.flat_map(&:runnable_loaders).reject(&:run?)
        end

        def grouped_records
          h = {}
          polymorphic_parent = !root? && parent.polymorphic?
          source_records.each do |record|
            reflection = record.class._reflect_on_association(association)
            next if polymorphic_parent && !reflection || !record.association(association).klass
            (h[reflection] ||= []) << record
          end
          h
        end

        def preloaders_for_reflection(reflection, reflection_records)
          reflection_records.group_by do |record|
            klass = record.association(association).klass

            if reflection.scope && reflection.scope.arity != 0
              # For instance dependent scopes, the scope is potentially
              # different for each record. To allow this we'll group each
              # object separately into its own preloader
              reflection_scope = reflection.join_scopes(klass.arel_table, klass.predicate_builder, klass, record).inject(&:merge!)
            end

            [klass, reflection_scope]
          end.map do |(rhs_klass, reflection_scope), rs|
            normalize_columns_list(rhs_klass, reflection)
            if @load_columns&.dig(rhs_klass.table_name.to_sym)&.any?
              if reflection_scope.nil?
                reflection_scope = rhs_klass.select(*@load_columns[rhs_klass.table_name.to_sym])
              else
                reflection_scope = reflection_scope.select(*@load_columns[rhs_klass.table_name.to_sym])
              end
            end
            preloader_for(reflection).new(rhs_klass, rs, reflection, scope, reflection_scope, associate_by_default, load_columns: @load_columns)
          end
        end

        def polymorphic?
          return false if root?
          return @polymorphic if defined?(@polymorphic)

          @polymorphic = source_records.any? do |record|
            reflection = record.class._reflect_on_association(association)
            reflection && reflection.options[:polymorphic]
          end
        end

        def loaders
          @loaders ||=
            grouped_records.flat_map do |reflection, reflection_records|
              preloaders_for_reflection(reflection, reflection_records)
            end
        end

        private
          def build_children(children)
            Array.wrap(children).flat_map { |association|
              Array(association).flat_map { |parent, child|
                Branch.new(
                  parent: self,
                  association: parent,
                  children: child,
                  associate_by_default: associate_by_default,
                  scope: scope,
                  load_columns: @load_columns
                )
              }
            }
          end

          # Returns a class containing the logic needed to load preload the data
          # and attach it to a relation. The class returned implements a `run` method
          # that accepts a preloader.
          def preloader_for(reflection)
            if reflection.options[:through]
              ThroughAssociation
            else
              Association
            end
          end

          def normalize_columns_list(rhs_klass, reflection)
            return unless @load_columns

            table_name = rhs_klass.table_name.to_sym
            columns_list = Array(@load_columns[table_name])
            columns_list = columns_list.map(&:to_s) & rhs_klass.column_names
            if columns_list.any?
              columns_list.unshift(rhs_klass.primary_key)
              columns_list << rhs_klass.inheritance_column
              if reflection.options[:through]
                through_table_name = reflection.through_reflection.klass.table_name.to_sym
                if @load_columns.key?(through_table_name)
                  @load_columns[through_table_name] << reflection.through_reflection.foreign_key
                  @load_columns[through_table_name] << reflection.source_reflection.foreign_key
                end
              end
              columns_list << reflection.foreign_key
              columns_list << reflection.type if reflection.options.key?(:as)
              self.children.map(&:association).each do |association|
                child_reflection = rhs_klass.reflect_on_association(association.to_sym)
                columns_list << child_reflection.foreign_key if child_reflection.macro == :belongs_to
              end
              @load_columns[table_name] = columns_list.map(&:to_s) & rhs_klass.column_names
            else
              @load_columns.delete(table_name)
            end
          end
      end
    end
  end
end

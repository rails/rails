# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Branch #:nodoc:
        attr_reader :association, :children, :parent
        attr_reader :scope, :associate_by_default
        attr_writer :preloaded_records

        def initialize(association:, children:, parent:, associate_by_default:, scope:)
          @association = association
          @parent = parent
          @scope = scope
          @associate_by_default = associate_by_default

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
          parent_classes.map do |parent_klass|
            parent_klass._reflect_on_association(@association)
          end.compact
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

          batched_record_batches_by_class = Hash.new { |h, k| h[k] = ActiveRecord::BatchedMethods::Batch.new(k) }

          source_records.each do |record|
            batched_method = record.class.batched_methods[association]
            if batched_method
              batch = batched_record_batches_by_class[record.class]
              record.batched_method_batch = batch
              next
            end

            reflection = record.class._reflect_on_association(association)
            next if polymorphic_parent && !reflection || !record.association(association).klass
            (h[reflection] ||= []) << record
          end
          h
        end

        def preloaders_for_reflection(reflection, reflection_records)
          reflection_records.group_by { |record| record.association(reflection.name).klass }.map do |rhs_klass, rs|
            preloader_for(reflection).new(rhs_klass, rs, reflection, scope, associate_by_default)
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
                  scope: scope
                )
              }
            }
          end

          # Returns a class containing the logic needed to load preload the data
          # and attach it to a relation. The class returned implements a `run` method
          # that accepts a preloader.
          def preloader_for(reflection)
            reflection.check_preloadable!

            if reflection.options[:through]
              ThroughAssociation
            else
              Association
            end
          end
      end
    end
  end
end

# frozen_string_literal: true

module ActiveRecord
  module Associations
    class SingularAssociation < Association # :nodoc:
      # Implements the reader method, e.g. foo.bar for Foo.has_one :bar
      def reader
        ensure_klass_exists!

        if !loaded? || stale_target?
          reload
        end

        target
      end

      # Implements the bang reader method, e.g. foo.bar! for Foo.has_one :bar.
      # Raises ActiveRecord::RecordNotFound when there is no associated record.
      def reader!
        reader || raise_association_not_found
      end

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        super
        @target = nil
        @future_target = nil
      end

      # Implements the writer method, e.g. foo.bar= for Foo.belongs_to :bar
      def writer(record)
        replace(record)
      end

      def build(attributes = nil, &block)
        record = build_record(attributes, &block)
        set_new_record(record)
        record
      end

      # Implements the reload reader method, e.g. foo.reload_bar for
      # Foo.has_one :bar
      def force_reload_reader
        reload(true)
        target
      end

      private
        def raise_association_not_found
          message = +"Couldn't find the #{reflection.name} association for #{owner.class.name}"

          if (primary_key = owner.class.primary_key) && !(id = owner.id).nil?
            message << " with #{primary_key}=#{id.inspect}"
          end

          raise RecordNotFound.new(message, klass&.name, klass&.primary_key)
        end

        def scope_for_create
          super.except!(*Array(klass.primary_key))
        end

        def find_target(async: false)
          if disable_joins
            if async
              scope.load_async.then(&:first)
            else
              scope.first
            end
          else
            super.then(&:first)
          end
        end

        def replace(record)
          raise NotImplementedError, "Subclasses must implement a replace(record) method"
        end

        def set_new_record(record)
          replace(record)
        end

        def _create_record(attributes, raise_error = false, &block)
          record = build_record(attributes, &block)
          saved = record.save
          set_new_record(record)
          raise RecordInvalid.new(record) if !saved && raise_error
          record
        end
    end
  end
end

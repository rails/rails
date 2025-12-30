# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActiveRecord
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

    def strict_loading_violation(event)
      owner = event.payload[:owner]
      reflection = event.payload[:reflection]

      emit_debug_event("active_record.strict_loading_violation",
        owner: owner.name,
        class: reflection.polymorphic? ? nil : reflection.klass.name,
        name: reflection.name,
      )
    end
    debug_only :strict_loading_violation

    def sql(event)
      payload = event.payload

      return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

      binds = nil

      if payload[:binds]&.any?
        casted_params = type_casted_binds(payload[:type_casted_binds])

        binds = []
        payload[:binds].each_with_index do |attr, i|
          attribute_name = if attr.respond_to?(:name)
            attr.name
          elsif attr.respond_to?(:[]) && attr[i].respond_to?(:name)
            attr[i].name
          else
            nil
          end

          filtered_params = filter(attribute_name, casted_params[i])

          binds << render_bind(attr, filtered_params)
        end
      end

      emit_debug_event("active_record.sql",
        async: payload[:async],
        name: payload[:name],
        sql: payload[:sql],
        cached: payload[:cached],
        lock_wait: payload[:lock_wait],
        binds: binds,
        duration_ms: event.duration.round(2),
      )
    end
    debug_only :sql

    private
      def type_casted_binds(casted_binds)
        casted_binds.respond_to?(:call) ? casted_binds.call : casted_binds
      end

      def render_bind(attr, value)
        case attr
        when ActiveModel::Attribute
          if attr.type.binary? && attr.value
            value = "<#{attr.value_for_database.to_s.bytesize} bytes of binary data>"
          end
        when Array
          attr = attr.first
        else
          attr = nil
        end

        [attr&.name, value]
      end

      def filter(name, value)
        ActiveRecord::Base.inspection_filter.filter_param(name, value)
      end
  end
end

ActiveRecord::StructuredEventSubscriber.attach_to :active_record

# frozen_string_literal: true

require "concurrent/map"

module ActionView
  class UnboundTemplate
    attr_reader :virtual_path, :details
    delegate :locale, :format, :variant, :handler, to: :@details

    def initialize(source, identifier, details:, virtual_path:)
      @source = source
      @identifier = identifier
      @details = details
      @virtual_path = virtual_path

      @templates = Concurrent::Map.new(initial_capacity: 2)
      @write_lock = Mutex.new
    end

    def bind_locals(locals)
      if template = @templates[locals]
        template
      else
        @write_lock.synchronize do
          normalized_locals = normalize_locals(locals)

          # We need ||=, both to dedup on the normalized locals and to check
          # while holding the lock.
          @templates[normalized_locals] ||= build_template(normalized_locals)

          # This may have already been assigned, but we've already de-dup'd so
          # reassignment is fine.
          @templates[locals.dup] = @templates[normalized_locals]
        end
      end
    end

    private
      def build_template(locals)
        Template.new(
          @source,
          @identifier,
          details.handler_class,

          format: details.format_or_default,
          variant: variant&.to_s,
          virtual_path: @virtual_path,

          locals: locals.map(&:to_s)
        )
      end

      def normalize_locals(locals)
        locals.map(&:to_sym).sort!.freeze
      end
  end
end

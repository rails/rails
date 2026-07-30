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

      @strict_locals_template = nil
      @templates = Concurrent::Map.new(initial_capacity: 2)
      @write_lock = Mutex.new
    end

    def bind_locals(locals)
      @strict_locals_template || @templates[locals] || build_bound_template(locals)
    end

    def built_templates # :nodoc:
      @strict_locals_template ? [@strict_locals_template] : @templates.values
    end

    def freeze # :nodoc:
      unless bind_locals([]).strict_locals?
        raise ArgumentError, "Cannot freeze #{@virtual_path.inspect}: templates must declare strict locals (e.g. `<%# locals: () %>`) to be frozen."
      end
      @source.freeze
      @identifier.freeze
      @virtual_path.freeze
      @details.freeze
      @strict_locals_template.freeze
      @templates = nil
      @write_lock = nil
      super
    end

    private
      def build_bound_template(locals)
        @write_lock.synchronize do
          return @strict_locals_template if @strict_locals_template
          normalized_locals = normalize_locals(locals)

          # We need ||=, both to dedup on the normalized locals and to check
          # while holding the lock.
          template = (@templates[normalized_locals] ||= build_template(normalized_locals))

          if template.strict_locals?
            @strict_locals_template = template
          else
            # This may have already been assigned, but we've already de-dup'd so
            # reassignment is fine.
            @templates[locals.dup] = template
          end

          template
        end
      end

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

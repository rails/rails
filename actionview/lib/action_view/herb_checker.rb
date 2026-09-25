# frozen_string_literal: true

# :markup: markdown

require "action_view/template/handlers/erb/herb"

module ActionView
  class HerbChecker # :nodoc:
    Failure = Data.define(:template, :error)

    def self.check(view_paths)
      handler = Template::Handlers::ERB.new

      view_paths.uniq.flat_map do |resolver|
        next [] unless resolver.respond_to?(:all_unbound_templates)

        unbound_templates = resolver.all_unbound_templates.select { |unbound|
          unbound.format == :html && unbound.handler == :erb
        }

        unbound_templates.filter_map { |unbound|
          template = unbound.bind_locals([])

          begin
            handler.call(template, template.source, implementation: Template::Handlers::ERB::Herb, validate_ruby: true)
            nil
          rescue ::Herb::Engine::CompilationError, ::Herb::Engine::SecurityError => error
            Failure.new(template, error)
          end
        }
      end
    end
  end
end

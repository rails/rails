# frozen_string_literal: true

# :markup: markdown

require "action_view/erb_compilation_cache"

module ActionView
  class ERBPrecompiler # :nodoc:
    Result = Data.define(:templates, :entries, :skipped_resolvers)

    class CompilationError < StandardError
      attr_reader :template

      def initialize(template, error)
        @template = template
        super("Failed to cache #{template.short_identifier}: #{error.message}")
      end
    end

    def self.call(resolvers)
      templates = 0
      skipped_resolvers = 0

      entries = ERBCompilationCache.build do
        resolvers.uniq.each do |resolver|
          unless resolver.respond_to?(:all_unbound_templates)
            skipped_resolvers += 1
            next
          end

          resolver.all_unbound_templates.each do |unbound|
            next unless unbound.handler == :erb

            template = unbound.bind_locals([])
            templates += 1

            begin
              template.strict_locals!
              template.handler.call(template, template.encode!)
            rescue => error
              raise CompilationError.new(template, error)
            end
          end
        end
      end

      Result.new(templates, entries.size, skipped_resolvers)
    end
  end
end

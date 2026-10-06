# frozen_string_literal: true

require "action_view/template"
require "fileutils"

module ActionView
  class TemplatePrecompiler # :nodoc:
    Result = Data.define(:templates, :skipped_resolvers)

    class CompilationError < StandardError
      def initialize(template, error)
        super("Failed to precompile #{template.identifier}: #{error.message}")
      end
    end

    def self.call(resolvers)
      unless directory = Template::CompilationCache.cache_dir
        raise "views:precompile requires Bootsnap with its compilation cache enabled"
      end

      FileUtils.remove_entry(directory) if File.directory?(directory)

      templates = skipped_resolvers = 0

      resolvers.uniq.each do |resolver|
        unless resolver.respond_to?(:all_unbound_templates)
          skipped_resolvers += 1
          next
        end

        resolver.all_unbound_templates.each do |unbound|
          template = unbound.bind_locals([])

          begin
            template.strict_locals!
            Template::CompilationCache.precompile(template, template.encode!)
          rescue StandardError, SyntaxError => error
            raise CompilationError.new(template, error)
          end

          templates += 1
        end
      end

      Result.new(templates, skipped_resolvers)
    end
  end
end

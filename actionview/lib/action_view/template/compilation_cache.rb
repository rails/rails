# frozen_string_literal: true

# :markup: markdown

require "fileutils"

module ActionView
  class Template
    module CompilationCache # :nodoc:
      PATH = "tmp/compiled_views"
      @entries = Ractor.make_shareable({})

      class << self
        def load(root)
          path = File.join(root, PATH)
          entries = File.file?(path) ? Marshal.load(File.binread(path)) : {}
          @entries = Ractor.make_shareable(entries)
        end

        def fetch(identifier)
          @entries[identifier]
        end

        def precompile(root, resolvers)
          path = File.join(root, PATH)
          FileUtils.rm_rf(path)
          entries = {}
          resolvers.each do |resolver|
            next unless resolver.respond_to?(:all_unbound_templates)

            resolver.all_unbound_templates.each do |unbound|
              template = unbound.bind_locals([])
              entries[template.identifier] = template.handler.call(template, template.encode!)
            end
          end

          FileUtils.mkdir_p(File.dirname(path))
          File.binwrite(path, Marshal.dump(entries))
        end
      end
    end
  end
end

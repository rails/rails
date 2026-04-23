# frozen_string_literal: true

require "action_view/render_parser"

module ActionView
  # Scans view template files for +render+ calls to extract which templates
  # are rendered and with which locals. Used by the template precompiler to
  # determine what templates to eagerly compile at boot.
  class TemplateScanner # :nodoc:
    def initialize(view_dir)
      @view_dir = view_dir
    end

    def template_renders
      results = []

      each_template do |relative_path, fullpath|
        handler_ext = File.basename(fullpath).split(".").last
        handler = Template.handler_for_extension(handler_ext)
        next unless handler

        source = File.read(fullpath)
        next unless source.include?("render")

        prefix = File.dirname(relative_path)
        prefix = "" if prefix == "."

        begin
          compiled_source = handler.call(FakeTemplate.new(fullpath), source)

          parser = RenderParser.new(relative_path, compiled_source)
          parser.render_calls_with_locals.each do |render_call|
            virtual_path = render_call.virtual_path
            unless virtual_path.include?("/")
              virtual_path = prefix.empty? ? virtual_path : "#{prefix}/#{virtual_path}"
            end

            results << [virtual_path, render_call.locals_keys.sort]
          end
        rescue => e
          raise e.class, "Error parsing template #{fullpath}: #{e.message}", e.backtrace
        end
      end

      results.uniq
    end

    private
      def each_template
        Dir["**/*", base: @view_dir].sort.each do |file|
          fullpath = File.expand_path(file, @view_dir)
          next if File.directory?(fullpath)
          yield file, fullpath
        end
      end

      class FakeTemplate # :nodoc:
        def initialize(identifier)
          @identifier = identifier
        end

        attr_reader :identifier

        def type
          nil
        end

        def format
          nil
        end
      end
  end
end

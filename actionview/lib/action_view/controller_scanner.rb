# frozen_string_literal: true

require "action_view/render_parser"

module ActionView
  # Scans controller source files for +render+ calls to extract which templates
  # are rendered and with which locals. Used by the template precompiler.
  class ControllerScanner # :nodoc:
    def initialize(controller_dir)
      @controller_dir = controller_dir
    end

    def template_renders
      results = []

      each_controller do |relative_path, fullpath|
        source = File.read(fullpath)
        next unless source.include?("render")

        controller_prefix = if relative_path =~ /\A(.*)_controller\.rb\z/
          $1
        end

        begin
          parser = RenderParser.new(relative_path, source, from_controller: true)
          parser.render_calls_with_locals.each do |render_call|
            virtual_path = render_call.virtual_path

            unless virtual_path.include?("/")
              next unless controller_prefix
              virtual_path = "#{controller_prefix}/#{virtual_path}"
            end

            results << [virtual_path, render_call.locals_keys.sort]
          end
        rescue => e
          raise e.class, "Error parsing controller #{fullpath}: #{e.message}", e.backtrace
        end
      end

      results.uniq
    end

    private
      def each_controller
        Dir["**/*.rb", base: @controller_dir].sort.each do |file|
          fullpath = File.expand_path(file, @controller_dir)
          next if File.directory?(fullpath)
          yield file, fullpath
        end
      end
  end
end

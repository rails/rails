# frozen_string_literal: true

require "action_view/render_parser"

module ActionView
  # Scans helper source files for +render+ calls to extract which templates
  # are rendered and with which locals. Used by the template precompiler.
  class HelperScanner # :nodoc:
    def initialize(helper_dir)
      @helper_dir = helper_dir
    end

    def template_renders
      results = []

      each_helper do |fullpath|
        source = File.read(fullpath)
        next unless source.include?("render")

        begin
          parser = RenderParser.new(fullpath, source)
          parser.render_calls_with_locals.each do |render_call|
            virtual_path = render_call.virtual_path
            results << [virtual_path, render_call.locals_keys.sort]
          end
        rescue => e
          raise e.class, "Error parsing helper #{fullpath}: #{e.message}", e.backtrace
        end
      end

      results.uniq
    end

    private
      def each_helper
        Dir["#{@helper_dir}/**/*_helper.rb"].sort.each do |fullpath|
          next if File.directory?(fullpath)
          yield fullpath
        end
      end
  end
end

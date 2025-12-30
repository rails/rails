# frozen_string_literal: true

module ActionView
  module RenderParser # :nodoc:
    ALL_KNOWN_KEYS = [:partial, :template, :layout, :formats, :locals, :object, :collection, :as, :status, :content_type, :location, :spacer_template]
    RENDER_TYPE_KEYS = [:partial, :template, :layout]

    class Base # :nodoc:
      def initialize(name, code)
        @name = name
        @code = code
      end

      private
        def directory
          File.dirname(@name)
        end

        def partial_to_virtual_path(render_type, partial_path)
          if render_type == :partial || render_type == :layout
            partial_path.gsub(%r{(/|^)([^/]*)\z}, '\1_\2')
          else
            partial_path
          end
        end
    end

    # Check if prism is available. If it is, use it. Otherwise, use ripper.
    begin
      require "prism"
    rescue LoadError
      require "ripper"
      require_relative "render_parser/ripper_render_parser"
      Default = RipperRenderParser
    else
      require_relative "render_parser/prism_render_parser"
      Default = PrismRenderParser
    end
  end
end

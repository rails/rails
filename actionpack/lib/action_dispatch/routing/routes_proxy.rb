# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/array/extract_options"

module ActionDispatch
  module Routing
    class RoutesProxy # :nodoc:
      include ActionDispatch::Routing::UrlFor

      attr_accessor :scope, :routes
      alias :_routes :routes

      def initialize(routes, scope, helpers, script_namer = nil)
        @routes, @scope = routes, scope
        @helpers = helpers
        @script_namer = script_namer
      end

      def url_options
        scope.send(:_with_routes, routes) do
          scope.url_options
        end
      end

    private
      def respond_to_missing?(method, _)
        super || @helpers.respond_to?(method)
      end

      def method_missing(method, *args)
        if @helpers.respond_to?(method)
          options = args.extract_options!
          options = url_options.merge((options || {}).symbolize_keys)

          if @script_namer
            options[:script_name] = merge_script_names(
              options[:script_name],
              @script_namer.call(options)
            )
          end

          args << options
          @helpers.public_send(method, *args)
        else
          super
        end
      end

      # Keeps the part of the script name provided by the global context via
      # [ENV]("SCRIPT_NAME"), which `mount` doesn't know about since it depends on the
      # specific request, but use our script name resolver for the mount point
      # dependent part.
      def merge_script_names(previous_script_name, new_script_name)
        return new_script_name unless previous_script_name
        new_script_name = new_script_name.chomp("/")

        resolved_parts = new_script_name.count("/")
        previous_parts = previous_script_name.count("/")
        context_parts = previous_parts - resolved_parts + 1

        (previous_script_name.split("/").slice(0, context_parts).join("/")) + new_script_name
      end
    end
  end
end

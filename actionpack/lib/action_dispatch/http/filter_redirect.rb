# frozen_string_literal: true

require "action_dispatch/http/parameter_filter"

module ActionDispatch
  module Http
    module FilterRedirect
      FILTERED = "[FILTERED]" # :nodoc:

      def filtered_location # :nodoc:
        location_filter_match
      end

    private
      def location_filters
        if request
          request.get_header("action_dispatch.redirect_filter") || []
        else
          []
        end
      end

      KV_RE   = "[^&;=]+"
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def location_filter_match
        location.deep_dup.gsub(PAIR_RE) do |_|
          ActionDispatch::Http::ParameterFilter.new(location_filters).filter($1 => $2).first.join("=")
        end
      end
    end
  end
end

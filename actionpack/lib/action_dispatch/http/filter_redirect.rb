# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Http
    module FilterRedirect
      FILTERED = "[FILTERED]" # :nodoc:

      def filtered_location # :nodoc:
        if location_filter_match?
          FILTERED
        else
          parameter_filtered_location
        end
      end

    private
      def location_filters
        if request
          request.get_header("action_dispatch.redirect_filter") || []
        else
          []
        end
      end

      def location_filter_match?
        location_filters.any? do |filter|
          if String === filter
            location.include?(filter)
          elsif Regexp === filter
            location.match?(filter)
          end
        end
      end

      def parameter_filtered_location
        uri = URI.parse(location)
        unless uri.query.nil? || uri.query.empty?
          uri.query.gsub!(FilterParameters::PAIR_RE) do
            request.parameter_filter.filter($1 => $2).first.join("=")
          end
        end
        uri.to_s
      rescue URI::Error
        FILTERED
      end
    end
  end
end

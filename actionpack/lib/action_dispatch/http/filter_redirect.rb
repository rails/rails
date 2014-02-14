module ActionDispatch
  module Http
    module FilterRedirect

      FILTERED = '[FILTERED]'.freeze # :nodoc:
      NULL_PARAM_FILTER = ParameterFilter.new # :nodoc:

      def filtered_location
        filters = location_filter
        if !filters.empty? && location_filter_match?(filters)
          FILTERED
        else
          parameter_filtered_location
        end
      end

    private

      def location_filter
        if request
          request.env['action_dispatch.redirect_filter'] || []
        else
          []
        end
      end

      def location_filter_match?(filters)
        filters.any? do |filter|
          if String === filter
            location.include?(filter)
          elsif Regexp === filter
            location.match(filter)
          end
        end
      end


      def parameter_filter
        ParameterFilter.new request.env.fetch("action_dispatch.parameter_filter") {
          return NULL_PARAM_FILTER
        }
      end

      KV_RE   = '[^&;=]+'
      PAIR_RE = %r{(#{KV_RE})=(#{KV_RE})}
      def parameter_filtered_location
        location.gsub(PAIR_RE) do |_|
          parameter_filter.filter([[$1, $2]]).first.join("=")
        end
      end

    end
  end
end

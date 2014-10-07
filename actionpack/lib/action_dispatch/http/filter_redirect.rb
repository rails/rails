module ActionDispatch
  module Http
    module FilterRedirect
      FILTERED = '[FILTERED]'.freeze # :nodoc:
      private_constant :FILTERED

      REDIRECT_FILTER = 'action_dispatch.redirect_filter'.freeze #:nodoc:
      private_constant :REDIRECT_FILTER

      def filtered_location
        filters = location_filter
        if !filters.empty? && location_filter_match?(filters)
          FILTERED
        else
          location
        end
      end

      private
      def location_filter
        if request
          request.env[REDIRECT_FILTER] || []
        else
          []
        end
      end

      private
      def location_filter_match?(filters)
        filters.any? do |filter|
          if String === filter
            location.include?(filter)
          elsif Regexp === filter
            location.match(filter)
          end
        end
      end
    end
  end
end

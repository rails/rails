module ActionDispatch
  module Http
    module FilterRedirect
      FILTERED = "[FILTERED]".freeze # :nodoc:

      def filtered_location # :nodoc:
        if location_filter_match?
          FILTERED
        else
          location
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
            location =~ filter
          end
        end
      end
    end
  end
end

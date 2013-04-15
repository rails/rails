module ActionDispatch
  module Http
    module FilterRedirect

      FILTERED = '[FILTERED]'.freeze # :nodoc:

      def filtered_location
        if !location_filter.empty? && location_filter_match?
          FILTERED
        else
          location
        end
      end

    private

      def location_filter
        if request.present?
          request.env['action_dispatch.redirect_filter'] || []
        else
          []
        end
      end

      def location_filter_match?
        location_filter.any? do |filter|
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

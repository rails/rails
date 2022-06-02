# frozen_string_literal: true

module ActionController
  module Head
    # Returns a response that has no content (merely headers). The options
    # argument is interpreted to be a hash of header names and values.
    # This allows you to easily return a response that consists only of
    # significant headers:
    #
    #   head :created, location: person_path(@person)
    #
    #   head :created, location: @person
    #
    # It can also be used to return exceptional conditions:
    #
    #   return head(:method_not_allowed) unless request.post?
    #   return head(:bad_request) unless valid_request?
    #   render
    #
    # See Rack::Utils::SYMBOL_TO_STATUS_CODE for a full list of valid +status+ symbols.
    def head(status, options = {})
      if status.is_a?(Hash)
        raise ArgumentError, "#{status.inspect} is not a valid value for `status`."
      end

      status ||= :ok

      location = options.delete(:location)
      content_type = options.delete(:content_type)

      options.each do |key, value|
        headers[key.to_s.split(/[-_]/).each { |v| v[0] = v[0].upcase }.join("-")] = value.to_s
      end

      self.status = status
      self.location = url_for(location) if location

      if include_content?(response_code)
        unless self.media_type
          self.content_type = content_type || (Mime[formats.first] if formats) || Mime[:html]
        end

        response.charset = false
      end

      self.response_body = ""

      true
    end

    private
      def include_content?(status)
        case status
        when 100..199
          false
        when 204, 205, 304
          false
        else
          true
        end
      end
  end
end

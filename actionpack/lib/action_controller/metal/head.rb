module ActionController
  module Head
    extend ActiveSupport::Concern

    # Return a response that has no content (merely headers). The options
    # argument is interpreted to be a hash of header names and values.
    # This allows you to easily return a response that consists only of
    # significant headers:
    #
    #   head :created, :location => person_path(@person)
    #
    # It can also be used to return exceptional conditions:
    #
    #   return head(:method_not_allowed) unless request.post?
    #   return head(:bad_request) unless valid_request?
    #   render
    def head(status, options = {})
      options, status = status, nil if status.is_a?(Hash)
      status ||= options.delete(:status) || :ok
      location = options.delete(:location)

      options.each do |key, value|
        headers[key.to_s.dasherize.split('-').each { |v| v[0] = v[0].chr.upcase }.join('-')] = value.to_s
      end

      self.status = status
      self.location = url_for(location) if location
      self.content_type = Mime[formats.first] if formats
      self.response_body = " "
    end
  end
end

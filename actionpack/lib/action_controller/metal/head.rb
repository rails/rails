module ActionController
  module Head
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
        headers[key.to_s.dasherize.split(/-/).map { |v| v.capitalize }.join("-")] = value.to_s
      end

      render :nothing => true, :status => status, :location => location
    end
  end
end
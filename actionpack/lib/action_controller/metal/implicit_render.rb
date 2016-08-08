require "active_support/core_ext/string/strip"

module ActionController
  # Handles implicit rendering for a controller action that does not
  # explicitly respond with +render+, +respond_to+, +redirect+, or +head+.
  #
  # For API controllers, the implicit response is always 204 No Content.
  #
  # For all other controllers, we use these heuristics to decide whether to
  # render a template, raise an error for a missing template, or respond with
  # 204 No Content:
  #
  # First, if we DO find a template, it's rendered. Template lookup accounts
  # for the action name, locales, format, variant, template handlers, and more
  # (see +render+ for details).
  #
  # Second, if we DON'T find a template but the controller action does have
  # templates for other formats, variants, etc., then we trust that you meant
  # to provide a template for this response, too, and we raise
  # <tt>ActionController::UnknownFormat</tt> with an explanation.
  #
  # Third, if we DON'T find a template AND the request is a page load in a web
  # browser (technically, a non-XHR GET request for an HTML response) where
  # you reasonably expect to have rendered a template, then we raise
  # <tt>ActionView::UnknownFormat</tt> with an explanation.
  #
  # Finally, if we DON'T find a template AND the request isn't a browser page
  # load, then we implicitly respond with 204 No Content.
  module ImplicitRender
    # :stopdoc:
    include BasicImplicitRender

    def default_render(*args)
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render(*args)
      elsif any_templates?(action_name.to_s, _prefixes)
        message = "#{self.class.name}\##{action_name} is missing a template " \
          "for this request format and variant.\n" \
          "\nrequest.formats: #{request.formats.map(&:to_s).inspect}" \
          "\nrequest.variant: #{request.variant.inspect}"

        raise ActionController::UnknownFormat, message
      elsif interactive_browser_request?
        message = "#{self.class.name}\##{action_name} is missing a template " \
          "for this request format and variant.\n\n" \
          "request.formats: #{request.formats.map(&:to_s).inspect}\n" \
          "request.variant: #{request.variant.inspect}\n\n" \
          "NOTE! For XHR/Ajax or API requests, this action would normally " \
          "respond with 204 No Content: an empty white screen. Since you're " \
          "loading it in a web browser, we assume that you expected to " \
          "actually render a template, not… nothing, so we're showing an " \
          "error to be extra-clear. If you expect 204 No Content, carry on. " \
          "That's what you'll get from an XHR or API request. Give it a shot."

        raise ActionController::UnknownFormat, message
      else
        logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
        super
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end

    private
      def interactive_browser_request?
        request.get? && request.format == Mime[:html] && !request.xhr?
      end
  end
end

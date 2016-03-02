require 'active_support/core_ext/string/strip'

module ActionController
  # Handles implicit rendering for a controller action when it did not
  # explicitly indicate an appropiate response via methods such as +render+,
  # +respond_to+, +redirect+ or +head+.
  #
  # For API controllers, the implicit render always renders "204 No Content"
  # and does not account for any templates.
  #
  # For other controllers, the following conditions are checked:
  #
  # First, if a template exists for the controller action, it is rendered.
  # This template lookup takes into account the action name, locales, format,
  # variant, template handlers, etc. (see +render+ for details).
  #
  # Second, if other templates exist for the controller action but is not in
  # the right format (or variant, etc.), an <tt>ActionController::UnknownFormat</tt>
  # is raised. The list of available templates is assumed to be a complete
  # enumeration of all the possible formats (or variants, etc.); that is,
  # having only HTML and JSON templates indicate that the controller action is
  # not meant to handle XML requests.
  #
  # Third, if the current request is an "interactive" browser request (the user
  # navigated here by entering the URL in the address bar, submiting a form,
  # clicking on a link, etc. as opposed to an XHR or non-browser API request),
  # <tt>ActionView::UnknownFormat</tt> is raised to display a helpful error
  # message.
  #
  # Finally, it falls back to the same "204 No Content" behavior as API controllers.
  module ImplicitRender

    # :stopdoc:
    include BasicImplicitRender

    def default_render(*args)
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render(*args)
      elsif any_templates?(action_name.to_s, _prefixes)
        message = "#{self.class.name}\##{action_name} does not know how to respond " \
          "to this request. There are other templates available for this controller " \
          "action but none of them were suitable for this request.\n\n" \
          "This usually happens when the client requested an unsupported format " \
          "(e.g. requesting HTML content from a JSON endpoint or vice versa), but " \
          "it might also be failing due to other constraints, such as locales or " \
          "variants.\n"

        if request.formats.any?
          message << "\nRequested format(s): #{request.formats.join(", ")}"
        end

        if request.variant.any?
          message << "\nRequested variant(s): #{request.variant.join(", ")}"
        end

        raise ActionController::UnknownFormat, message
      elsif interactive_browser_request?
        message = "You did not define any templates for #{self.class.name}\##{action_name}. " \
          "This is not necessarily a problem (e.g. you might be building an API endpoint " \
          "that does not require any templates), and the controller would usually respond " \
          "with `head :no_content` for your convenience.\n\n" \
          "However, you appear to have navigated here from an interactive browser request – " \
          "such as by navigating to this URL directly, clicking on a link or submitting a form. " \
          "Rendering a `head :no_content` in this case could have resulted in unexpected UI " \
          "behavior in the browser.\n\n" \
          "If you expected the `head :no_content` response, you do not need to take any " \
          "actions – requests coming from an XHR (AJAX) request or other non-browser clients " \
          "will receive the \"204 No Content\" response as expected.\n\n" \
          "If you did not expect this behavior, you can resolve this error by adding a " \
          "template for this controller action (usually `#{action_name}.html.erb`) or " \
          "otherwise indicate the appropriate response in the action using `render`, " \
          "`redirect_to`, `head`, etc.\n"

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
        request.format == Mime[:html] && !request.xhr?
      end
  end
end

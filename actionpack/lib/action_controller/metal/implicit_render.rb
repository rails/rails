module ActionController
  module ImplicitRender

    include BasicImplicitRender

    # Renders the template corresponding to the controller action, if it exists.
    # The action name, format, and variant are all taken into account.
    # For example, the "new" action with an HTML format and variant "phone" 
    # would try to render the <tt>new.html+phone.erb</tt> template.
    #
    # If no template is found and a block is passed, then the block is called 
    # to allow the caller to handle the missing template. If no block is passed 
    # and it's an HTML, non-XHR (interactive browser) request, then 
    # <tt>ActionView::MissingTemplate</tt> is raised. Otherwise, 
    # <tt>ActionController::BasicImplicitRender</tt>'s implementation is called.
    #
    #   default_render do
    #     head 404 # No template was found
    #   end
    def default_render(*args) 
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render(*args)
      else
        if block_given?
          yield(*args)
        else
          logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
          if interactive_browser_request?
            # calling render will raise ActionView::MissingTemplate because 
            # the template's not there, and that's the exception we want
            render(*args) 
          else
            super
          end
        end
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end

    def interactive_browser_request?
      request.format == Mime[:html] && !request.xhr?
    end
  end
end

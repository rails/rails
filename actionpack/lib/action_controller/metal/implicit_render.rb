module ActionController
  module ImplicitRender

    include BasicImplicitRender

    # Renders the template corresponding to the controller action, if it exists.
    # The action name, format, and variant are all taken into account.
    # For example, the "new" action with an HTML format and variant "phone" 
    # would try to render the <tt>new.html+phone.erb</tt> template.
    #
    # If no template is found <tt>ActionController::BasicImplicitRender</tt>'s implementation is called, unless
    # a block is passed. In that case, it will override the super implementation.
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
          super
        end
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end
  end
end

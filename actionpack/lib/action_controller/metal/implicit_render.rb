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
          if no_templates? && no_response_handler?
            # `head :no_content` is returned if...
            #   - An action has no templates defined at all, and it has no `respond_to {}` block
            logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
            super
          else
            # `ActionController::UnknownFormat` is returned if...
            #   - An action has certain templates defined, and it has no `respond_to {}` block
            #   - An action has a `respond_to {}` block, and there is no handler for the request format and/or variant
            format = request.format.to_s
            logger.info "No template found for #{self.class.name}\##{action_name} in #{format} format" if logger
            raise ActionController::UnknownFormat
          end
        end
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end

    private
      def no_response_handler?
        !formats.include?(request.format.symbol) || !request.negotiate_mime(request.variant)
      end

      def no_templates?
        # Check and see if any templates exist for the given action name, and prefixes.
        !@_lookup_context.any?(action_name.to_s, _prefixes)
      end
  end
end

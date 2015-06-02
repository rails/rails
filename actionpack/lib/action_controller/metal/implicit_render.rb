module ActionController
  module ImplicitRender

    include BasicImplicitRender

    def default_render(*args)
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render(*args)
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
  end
end

module ActionController
  module ImplicitRender
    def send_action(method, *args)
      ret = super
      default_render unless performed?
      ret
    end

    def default_render(*args)
      if template_exists?(action_name.to_s, _prefixes, variants: request.variant)
        render(*args)
      else
        logger.info "No template found for #{self.class.name}\##{action_name}, rendering head :no_content" if logger
        head :no_content
      end
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end
  end
end

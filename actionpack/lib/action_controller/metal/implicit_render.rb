module ActionController
  module ImplicitRender
    def send_action(method, *args)
      if respond_to?(method, true)
        ret = super
        default_render unless response_body
        ret
      else
        default_render
      end
    end

    def default_render
      render
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefix)
        action_name.to_s
      end
    end
  end
end
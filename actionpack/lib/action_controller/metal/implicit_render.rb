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

    def default_render(*args)
      render(*args)
    end

    def action_method?(action_name)
      super || template_exists?(action_name.to_s, _prefixes)
    end
  end
end

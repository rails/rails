module ActionController
  module ImplicitRender
    def send_action(method, *args)
      ret = super
      default_render unless performed?
      ret
    end

    def default_render(*args)
      render(*args)
    end

    def method_for_action(action_name)
      super || if template_exists?(action_name.to_s, _prefixes)
        "default_render"
      end
    end
  end
end

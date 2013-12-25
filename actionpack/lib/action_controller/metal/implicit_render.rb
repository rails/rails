module ActionController
  module ImplicitRender
    def send_action(method, *args)
      ret = super
      unless performed?
        lookup_context.rendered_format = nil
        default_render
      end
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

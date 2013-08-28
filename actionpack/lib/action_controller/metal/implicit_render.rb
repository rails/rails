module ActionController
  module ImplicitRender
    def send_action(method, *args)
      ret = super
      unless performed?
        if implicit_render?
          default_render
        elsif
          raise ActionController::BasicRendering::NoRenderError
        end
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

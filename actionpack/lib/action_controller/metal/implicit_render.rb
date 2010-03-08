module ActionController
  module ImplicitRender
    def send_action(*)
      ret = super
      default_render unless response_body
      ret
    end

    def default_render
      render
    end

    def method_for_action(action_name)
      super || begin
        if template_exists?(action_name.to_s, _prefix)
          "default_render"
        end
      end
    end
  end
end
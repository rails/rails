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
        # TODO This should use template lookup
        if view_paths.exists?(action_name.to_s, details_for_render, controller_path)
          "default_render"
        end
      end
    end
  end
end
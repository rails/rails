module ActionController
  module ImplicitRender

    def send_action(method, *args)
      ret = super
      unless response_body
        if template_exists?(action_name.to_s, _prefixes)
          default_render
        else
          process_not_found_template
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

    protected

    # if lookup template not exist then go to check if any template existed,
    # if so show 406, if not, go render, it will give MissingTemplate error.
    def process_not_found_template(*args)
      provided_any_template = begin
                                old_formats, lookup_context.formats = lookup_context.formats, Mime::SET.symbols
                                template_exists?(action_name.to_s, _prefixes)
                              ensure
                                lookup_context.formats = old_formats
                              end

      provided_any_template ? head(:not_acceptable) : render(*args)
    end
  end
end

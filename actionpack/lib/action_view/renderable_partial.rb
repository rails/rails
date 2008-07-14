module ActionView
  module RenderablePartial
    # NOTE: The template that this mixin is beening include into is frozen
    # So you can not set or modify any instance variables

    def variable_name
      @variable_name ||= name.gsub(/^_/, '').to_sym
    end

    def counter_name
      @counter_name ||= "#{variable_name}_counter".to_sym
    end

    def freeze
      # Eager load and freeze memoized methods
      variable_name.freeze
      counter_name.freeze
      super
    end

    def render(view, local_assigns = {})
      ActionController::Base.benchmark("Rendered #{path_without_format_and_extension}", Logger::DEBUG, false) do
        super
      end
    end

    def render_partial(view, object = nil, local_assigns = {}, as = nil)
      object ||= local_assigns[:object] ||
        local_assigns[variable_name] ||
        view.controller.instance_variable_get("@#{variable_name}") if view.respond_to?(:controller)

      # Ensure correct object is reassigned to other accessors
      local_assigns[:object] = local_assigns[variable_name] = object
      local_assigns[as] = object if as

      render_template(view, local_assigns)
    end
  end
end

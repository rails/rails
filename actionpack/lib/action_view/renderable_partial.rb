module ActionView
  # NOTE: The template that this mixin is being included into is frozen
  # so you cannot set or modify any instance variables
  module RenderablePartial #:nodoc:
    extend ActiveSupport::Memoizable

    def variable_name
      name.sub(/\A_/, '').to_sym
    end
    memoize :variable_name

    def counter_name
      "#{variable_name}_counter".to_sym
    end
    memoize :counter_name

    def render(view, local_assigns = {})
      if defined? ActionController
        ActionController::Base.benchmark("Rendered #{path_without_format_and_extension}", Logger::DEBUG, false) do
          super
        end
      else
        super
      end
    end

    def render_partial(view, object = nil, local_assigns = {}, as = nil)
      object ||= local_assigns[:object] || local_assigns[variable_name]

      if object.nil? && !local_assigns_key?(local_assigns) && view.respond_to?(:controller)
        ivar = :"@#{variable_name}"
        object =
          if view.controller.instance_variable_defined?(ivar)
            ActiveSupport::Deprecation::DeprecatedObjectProxy.new(
              view.controller.instance_variable_get(ivar),
              "#{ivar} will no longer be implicitly assigned to #{variable_name}")
          end
      end

      # Ensure correct object is reassigned to other accessors
      local_assigns[:object] = local_assigns[variable_name] = object
      local_assigns[as] = object if as

      render_template(view, local_assigns)
    end

    private

      def local_assigns_key?(local_assigns)
        local_assigns.key?(:object) || local_assigns.key?(variable_name)
      end
  end
end

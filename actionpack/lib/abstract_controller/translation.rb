# frozen_string_literal: true

# :markup: markdown

require "active_support/html_safe_translation"

module AbstractController
  module Translation
    # Delegates to `I18n.translate`.
    #
    # When the key or the `:scope` option starts with a period, it will be
    # scoped by the current controller and action. So if you call
    # `translate(".foo")` from `PeopleController#index`, it will convert the
    # call to `I18n.translate("people.index.foo")`; calling
    # `translate("bar", scope: ".foo")` converts to
    # `I18n.translate("bar", scope: "people.index.foo")`. This makes it less
    # repetitive to translate many keys within the same controller / action
    # and gives you a simple framework for scoping them consistently. The
    # key takes precedence: if the key itself starts with a period, the
    # `:scope` option's own leading period is left as-is rather than
    # expanded, preserving the pre-existing behavior for calls like
    # `translate(".bar", scope: ".foo")`.
    def translate(key, **options)
      if key&.start_with?(".")
        defaults = [:"#{controller_scope}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults.flatten
        key = "#{controller_action_scope}#{key}"
      elsif (scope = options[:scope])
        options[:scope] = scope_option_by_controller_path(scope)
      end

      if options[:default] && ActiveSupport::HtmlSafeTranslation.html_safe_translation_key?(key)
        options[:default] = Array(options[:default]).map do |value|
          value.is_a?(String) ? ERB::Util.html_escape(value) : value
        end
      end

      ActiveSupport::HtmlSafeTranslation.translate(key, **options)
    end
    alias :t :translate

    # Delegates to `I18n.localize`.
    def localize(object, **options)
      I18n.localize(object, **options)
    end
    alias :l :localize

    private
      def controller_scope
        controller_path.tr("/", ".")
      end

      def controller_action_scope
        "#{controller_scope}.#{action_name}"
      end

      def scope_option_by_controller_path(scope)
        if (scope.is_a?(String) || scope.is_a?(Symbol)) && scope.start_with?(".")
          resolved = "#{controller_action_scope}#{scope}"
          scope.is_a?(Symbol) ? resolved.to_sym : resolved
        else
          scope
        end
      end
  end
end

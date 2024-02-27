# frozen_string_literal: true

# :markup: markdown

require "active_support/html_safe_translation"

module AbstractController
  module Translation
    # Delegates to `I18n.translate`.
    #
    # When the given key starts with a period, it will be scoped by the current
    # controller and action. So if you call `translate(".foo")` from
    # `PeopleController#index`, it will convert the call to
    # `I18n.translate("people.index.foo")`. This makes it less repetitive to
    # translate many keys within the same controller / action and gives you a simple
    # framework for scoping them consistently.
    def translate(key, **options)
      if key&.start_with?(".")
        path = controller_path.tr("/", ".")
        defaults = [:"#{path}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults.flatten
        key = "#{path}.#{action_name}#{key}"
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
  end
end

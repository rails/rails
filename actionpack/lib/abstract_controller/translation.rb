# frozen_string_literal: true

require "active_support/html_safe_translation"

module AbstractController
  module Translation
    mattr_accessor :raise_on_missing_translations, default: false

    # Delegates to <tt>I18n.translate</tt>.
    #
    # When the given key starts with a period, it will be scoped by the current
    # controller and action. So if you call <tt>translate(".foo")</tt> from
    # <tt>PeopleController#index</tt>, it will convert the call to
    # <tt>I18n.translate("people.index.foo")</tt>. This makes it less repetitive
    # to translate many keys within the same controller / action and gives you a
    # simple framework for scoping them consistently.
    def translate(key, **options)
      if key&.start_with?(".")
        path = controller_path.tr("/", ".")
        defaults = [:"#{path}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults.flatten
        key = "#{path}.#{action_name}#{key}"
      end

      i18n_raise = options.fetch(:raise, self.raise_on_missing_translations)

      if options[:default]
        options[:default] = [options[:default]] unless options[:default].is_a?(Array)
        options[:default] = options[:default].map do |value|
          value.is_a?(String) ? ERB::Util.html_escape(value) : value
        end
      end

      unless i18n_raise
        options[:default] = [] unless options[:default]
        options[:default] << MISSING_TRANSLATION
      end

      result = ActiveSupport::HtmlSafeTranslation.translate(key, **options, raise: i18n_raise)

      if result == MISSING_TRANSLATION
        +"translation missing: #{key}"
      else
        result
      end
    end
    alias :t :translate

    # Delegates to <tt>I18n.localize</tt>.
    def localize(object, **options)
      I18n.localize(object, **options)
    end
    alias :l :localize

    private
      MISSING_TRANSLATION = -(2**60)
      private_constant :MISSING_TRANSLATION
  end
end

# frozen_string_literal: true

module AbstractController
  module Translation
    mattr_accessor :raise_on_missing_translations, default: false

    # Delegates to <tt>I18n.translate</tt>. Also aliased as <tt>t</tt>.
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

      if html_safe_translation_key?(key)
        html_safe_options = options.dup
        options.except(*I18n::RESERVED_KEYS).each do |name, value|
          unless name == :count && value.is_a?(Numeric)
            html_safe_options[name] = ERB::Util.html_escape(value.to_s)
          end
        end
        translation = I18n.translate(key, **html_safe_options, raise: i18n_raise)

        translation.respond_to?(:html_safe) ? translation.html_safe : translation
      else
        I18n.translate(key, **options, raise: i18n_raise)
      end
    end
    alias :t :translate

    # Delegates to <tt>I18n.localize</tt>. Also aliased as <tt>l</tt>.
    def localize(object, **options)
      I18n.localize(object, **options)
    end
    alias :l :localize

    private
      def html_safe_translation_key?(key)
        /(\b|_|\.)html$/.match?(key.to_s)
      end
  end
end

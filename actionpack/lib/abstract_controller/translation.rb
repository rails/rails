module AbstractController
  module Translation
    # Delegates to <tt>I18n.translate</tt>. Also aliased as <tt>t</tt>.
    #
    # When the given key starts with a period, it will be scoped by the current
    # controller and action. So if you call <tt>translate(".foo")</tt> from
    # <tt>PeopleController#index</tt>, it will convert the call to
    # <tt>I18n.translate("people.index.foo")</tt>. This makes it less repetitive
    # to translate many keys within the same controller / action and gives you a
    # simple framework for scoping them consistently.
    #
    # It will mark the translation as safe HTML if the key has the suffix
    # "_html" or the last element of the key is the word "html". For example,
    # calling translate("footer_html") or translate("footer.html") will return
    # a safe HTML string that won't be escaped by other HTML helper methods. This
    # naming convention helps to identify translations that include HTML tags so that
    # you know what kind of output to expect when you call translate in a template.
    def translate(key, options = {})
      key, options = scope_key_and_options_by_partial(key, options)

      if html_safe_translation_key?(key)
        html_safe_options = options.dup
        options.except(*I18n::RESERVED_KEYS).each do |name, value|
          unless name == :count && value.is_a?(Numeric)
            html_safe_options[name] = ERB::Util.html_escape(value.to_s)
          end
        end
        translation = I18n.translate(key, html_safe_options)

        translation.respond_to?(:html_safe) ? translation.html_safe : translation
      else
        I18n.translate(key, options)
      end
    end
    alias :t :translate

    # Delegates to <tt>I18n.localize</tt>. Also aliased as <tt>l</tt>.
    def localize(*args)
      I18n.localize(*args)
    end
    alias :l :localize

    private

    def scope_key_and_options_by_partial(key, options)
      if key.to_s.first == '.'
        path = controller_path.tr('/', '.')
        defaults = [:"#{path}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults
        key = "#{path}.#{action_name}#{key}"
      end
      [key, options]
    end

    def html_safe_translation_key?(key)
      key.to_s =~ /(\b|_|\.)html$/
    end
  end
end

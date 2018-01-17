# frozen_string_literal: true

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
    def translate(key, options = {})
      if key.to_s.first == "."
        path = controller_path.tr("/", ".")
        defaults = [:"#{path}#{key}"]
        defaults << options[:default] if options[:default]
        options[:default] = defaults.flatten
        key = "#{path}.#{action_name}#{key}"
      end
      I18n.translate(key, options)
    end
    alias :t :translate

    def current_scope
      "#{controller_path.tr('/', '.')}.#{action_name}"
    end

    # Delegates to <tt>I18n.localize</tt>. Also aliased as <tt>l</tt>.
    def localize(*args)
      I18n.localize(*args)
    end
    alias :l :localize
  end
end

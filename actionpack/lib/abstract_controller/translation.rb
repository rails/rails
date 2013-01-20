module AbstractController
  module Translation
    # Delegates to <tt>I18n#translate</tt> but also performs one additional function.
    #
    # It'll scope the key by the current action if the key starts
    # with a period. So if you call <tt>translate(".foo")</tt> from the
    # <tt>PeopleController#index</tt> action, you'll actually be calling
    # <tt>I18n.translate("people.index.foo")</tt>. This makes it less repetitive
    # to translate many keys within the same controller / action and gives you a simple framework
    # for scoping them consistently. If you don't prepend the key with a period,
    # nothing is converted.
    def translate(*args)
      key = args.first
      if key.is_a?(String) && (key[0] == '.')
        key = "#{ controller_path.gsub('/', '.') }.#{ action_name }#{ key }"
        args[0] = key
      end

      I18n.translate(*args)
    end
    alias :t :translate

    # Delegates to <tt>I18n.localize</tt> with no additional functionality.
    def localize(*args)
      I18n.localize(*args)
    end
    alias :l :localize
  end
end

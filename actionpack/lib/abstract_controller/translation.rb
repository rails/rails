module AbstractController
  module Translation
    def translate(*args)
      key = args.first
      if key.is_a?(String) && (key[0] == '.')
        key = "#{ controller_path.gsub('/', '.') }.#{ action_name }#{ key }"
        args[0] = key
      end

      I18n.translate(*args)
    end
    alias :t :translate

    def localize(*args)
      I18n.localize(*args)
    end
    alias :l :localize
  end
end

module ActionController
  module Translation
    def translate(*args)
      I18n.translate *args
    end
    alias :t :translate

    def localize(*args)
      I18n.localize *args
    end
    alias :l :localize
  end
end
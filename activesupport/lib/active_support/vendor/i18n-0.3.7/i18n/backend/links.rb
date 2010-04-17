module I18n
  module Backend
    module Links
      protected
        def links(locale)
          @links ||= {}
          @links[locale.to_sym] ||= {}
        end

        def store_link(locale, key, link)
          links(locale)[key.to_s] = link.to_s
        end

        def resolve_link(locale, key)
          key   = key.to_s
          links = self.links(locale)

          if links.key?(key)
            links[key]
          elsif link = find_link(locale, key)
            store_link(locale, key, key.gsub(*link))
          else
            key
          end
        end

        def find_link(locale, key)
          links(locale).each do |from, to|
            return [from, to] if key[0, from.length] == from
          end && nil
        end
    end
  end
end
module ActionView
  class TemplateEagerLoader
    def self.do(o)
      partial = false
      locals = []

      prefixes = Dir.glob('app/views/*').map { |name| name.split('/').last }
      prefixes.each do |prefix|

        path_names = Dir.glob("app/views/#{prefix}/*").map { |name| File.basename name }
        path_names.each do |name|
          locales.each do |locale|
            pieces = name.split('.')
            keyh = {
              locale: locale,
              formats: Mime::SET.collect(&:symbol),
              variants: variants(pieces),
              handlers: ActionView::Template::Handlers.extensions
            }
            key = ActionView::LookupContext::DetailsKey.get(keyh)
            o._view_paths.paths.first.instance_variable_get(:@cache).cache(key, pieces.first, prefix, partial, locals) do
              o._view_paths.paths.first.find_all(pieces.first, prefix, partial, keyh, locals)
            end
          end
        end
      end
    end

    def self.variants(pieces)
      separator = ActionView::PathResolver::EXTENSIONS[:variants]
      pieces.pop
      parts = pieces.last.split(separator)
      parts.length > 1 ? [parts.last] : []
    end

    # All possible locale combinations
    def self.locales
      locales = [[:en]]
      available = I18n.available_locales - [:en]
      available.each do |locale|
        locales << [locale, :en]
        available.each do |default|
          next if locale == default
          locales << [locale, :en, default]
        end
      end
      locales
    end
  end
end

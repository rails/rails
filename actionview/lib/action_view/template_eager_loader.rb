module ActionView
  class TemplateEagerLoader

    def initialize(resolver)
      @resolver = resolver
    end

    def eager_load
      prefixes.each do |prefix|
        path_names(prefix).each do |name|
          locales.each do |locale|
            pieces = name.split('.')
            details, key = details_and_key(locale, name, pieces)
            action = pieces.first
            partial, locals = partial_and_locals(action)
            action = action[1..-1] if action[0] == '_'
            @resolver.find_all(action, prefix, partial, details, key, locals)
          end
        end
      end
    end

    private

    def templates(action, prefix, partial, details, key, locals)
      templates = @resolver.find_all(action, prefix, partial, details, key, locals)
      templates.nil? ? [] : templates
    end

    def prefixes
      prefixes = view_paths.map { |name| name.split('app/views/').last }
      prefixes.map { |prefix| prefix.split(File.basename prefix).first[0..-2] }.uniq
    end

    def details_and_key(locale, name, pieces)
      details = {
        locale: locale,
        formats: formats(name),
        variants: variants(pieces),
        handlers: ActionView::Template::Handlers.extensions
      }
      return details, ActionView::LookupContext::DetailsKey.get(details)
    end

    def partial_and_locals(action)
      partial = false
      locals = []
      if action[0] == '_'
        partial = true
        action = action[1..-1]
        locals << action
        locals << action + '_counter'
        locals << action + '_iteration'
      end
      return partial, [locals] if locals == []
      return partial, [[], locals]
    end

    # All possible locale combinations
    def locales
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

    def view_paths
      @view_paths ||= Dir.glob('app/views/**/*.*')
    end

    def path_names(prefix)
      view_paths_for(prefix).map { |name| File.basename(name) }
    end

    def view_paths_for(prefix)
      view_paths.select { |i| i.match(%r{\Aapp/views/#{prefix}/[^/]+\.+[^/]+\z}) }
    end

    def variants(pieces)
      separator = ActionView::PathResolver::EXTENSIONS[:variants]
      parts = name_parts[0..-2].last.split(separator)
      parts.length > 1 ? [parts.last] : []
    end

    def all_formats
      Mime::SET.collect(&:symbol)
    end

    def formats(name)
      format = name.split('.')[-2].to_sym
      all_formats.include?(format) ? [format] : [:html]
    end

    cattr_accessor :eager_load_templates

    class << self
      alias :eager_load_templates? :eager_load_templates
    end
  end
end

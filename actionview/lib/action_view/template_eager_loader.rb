module ActionView
  # Does stuff.
  class TemplateEagerLoader

    def initialize(resolver)
      @resolver = resolver
    end

    def eager_load
      each_template(&:compile!)
    end

    private

    def each_template(&block)
      prefixes.each do |prefix|
        path_names(prefix).each do |name|
          locales.each do |locale|
            details, key, action, partial, locals = set_template_parameters(locale, name)
            locals.each do |locals_array|
              @resolver.find_all(action, prefix, partial, details, key, locals_array).each(&block)
            end
          end
        end
      end
    end

    def set_template_parameters(locale, name)
      name_parts, partial = name_parts_and_partial(name)
      details, key = details_and_key(locale, name, name_parts)
      action = action_without_partial_underscore(name_parts.first, partial)
      locals = partial ? locals(action) : [[]]
      [details, key, action, partial, locals]
    end

    def action_without_partial_underscore(name, partial)
      partial ? name[1..-1] : name
    end

    def name_parts_and_partial(name)
      name_parts = name.split('.')
      [name_parts, name_parts.first.start_with?('_')]
    end

    def prefixes
      prefixes = view_paths.map { |name| name.split('app/views/').last }
      prefixes.map { |prefix| prefix.split(File.basename prefix).first[0..-2] }.uniq
    end

    def details_and_key(locale, name, name_parts)
      details = {
        locale: locale,
        formats: formats(name),
        variants: variants(name_parts),
        handlers: ActionView::Template::Handlers.extensions
      }
      [details, ActionView::LookupContext::DetailsKey.get(details)]
    end

    def locals(action)
      locals = []
      locals << action
      locals << action + '_counter'
      locals << action + '_iteration'
      [[], locals]
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
      view_paths_for(prefix).map { |path| File.basename(path) }
    end

    def view_paths_for(prefix)
      view_paths.select { |i| i.match(%r{\Aapp/views/#{prefix}/[^/]+\.+[^/]+\z}) }
    end

    def variants(name_parts)
      separator = ActionView::PathResolver::EXTENSIONS[:variants]
      parts = name_parts[0..-2].last.split(separator)
      parts.length > 1 ? [parts.last] : []
    end

    def variant_separator
      Regexp.escape(ActionView::PathResolver::EXTENSIONS[:variants])
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

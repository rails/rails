module ActionView
  # = Action View Template Eager Loader
  class TemplateEagerLoader # :nodoc:
    # ActionView::TemplateEagerLoader finds and caches all
    # view templates and then compiles them.
    #
    # If this is done on server startup,
    # the first request will be faster.

    def initialize(resolver)
      @resolver = resolver
    end

    # Compiles and caches all templates
    def eager_load
      each_template(&:compile!)
    end

    private

    # Determines all possible template parameters and then
    # delegates finding and caching to the Resolver.
    # After finding and caching the templates, it will
    # yield them to the block.
    def each_template(&block)
      views.each do |prefix, name|
        locales.each do |locale|
          details, key, action, partial, locals = set_template_parameters(locale, name)
          locals.each do |locals_array|
            @resolver.find_all(action, prefix, partial, details, key, locals_array).each(&block)
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
      @resolver.paths.map(&:to_path).flat_map do |base_path|
        Dir.glob("#{base_path}/**/*.*").map do |path|
          path.sub("#{base_path}/", '')
        end
      end
    end

    def views
      view_paths.map do |path|
        name = path.split('/').last
        prefix = path.split('/')[0..-2].join('/')
        [prefix, name]
      end
    end

    def variants(name_parts)
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

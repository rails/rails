require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActionView
  # = Action View Lookup Context
  #
  # LookupContext is the object responsible to hold all information required to lookup
  # templates, i.e. view paths and details. The LookupContext is also responsible to
  # generate a key, given to view paths, used in the resolver cache lookup. Since
  # this key is generated just once during the request, it speeds up all cache accesses.
  class LookupContext #:nodoc:
    attr_accessor :prefixes

    mattr_accessor :fallbacks
    @@fallbacks = FallbackFileSystemResolver.instances

    mattr_accessor :registered_details
    self.registered_details = []

    mattr_accessor :registered_detail_setters
    self.registered_detail_setters = []

    def self.register_detail(name, options = {}, &block)
      self.registered_details << name
      self.registered_detail_setters << [name, "#{name}="]

      Accessors.send :define_method, :"_#{name}_defaults", &block
      Accessors.module_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{name}
          @details[:#{name}]
        end

        def #{name}=(value)
          value = Array.wrap(value.presence || _#{name}_defaults)
          _set_detail(:#{name}, value) if value != @details[:#{name}]
        end
      METHOD
    end

    # Holds accessors for the registered details.
    module Accessors #:nodoc:
    end

    register_detail(:formats) { Mime::SET.symbols }
    register_detail(:locale)  { [I18n.locale, I18n.default_locale] }

    class DetailsKey #:nodoc:
      alias :eql? :equal?
      alias :object_hash :hash

      attr_reader :hash
      @details_keys = Hash.new

      def self.get(details)
        @details_keys[details.freeze] ||= new
      end

      def initialize
        @hash = object_hash
      end
    end

    def initialize(view_paths, details = {}, prefixes = [])
      @details, @details_key = { :handlers => default_handlers }, nil
      @frozen_formats, @skip_default_locale = false, false
      @cache = true
      @prefixes = prefixes

      self.view_paths = view_paths
      self.registered_detail_setters.each do |key, setter|
        send(setter, details[key])
      end
    end

    module ViewPaths
      attr_reader :view_paths

      # Whenever setting view paths, makes a copy so we can manipulate then in
      # instance objects as we wish.
      def view_paths=(paths)
        @view_paths = ActionView::Base.process_view_paths(paths)
      end

      def find(name, prefixes = [], partial = false, keys = [])
        @view_paths.find(*args_for_lookup(name, prefixes, partial, keys))
      end
      alias :find_template :find

      def find_all(name, prefixes = [], partial = false, keys = [])
        @view_paths.find_all(*args_for_lookup(name, prefixes, partial, keys))
      end

      def exists?(name, prefixes = [], partial = false, keys = [])
        @view_paths.exists?(*args_for_lookup(name, prefixes, partial, keys))
      end
      alias :template_exists? :exists?

      # Add fallbacks to the view paths. Useful in cases you are rendering a :file.
      def with_fallbacks
        added_resolvers = 0
        self.class.fallbacks.each do |resolver|
          next if view_paths.include?(resolver)
          view_paths.push(resolver)
          added_resolvers += 1
        end
        yield
      ensure
        added_resolvers.times { view_paths.pop }
      end

    protected

      def args_for_lookup(name, prefixes, partial, keys) #:nodoc:
        name, prefixes = normalize_name(name, prefixes)
        [name, prefixes, partial || false, @details, details_key, keys]
      end

      # Support legacy foo.erb names even though we now ignore .erb
      # as well as incorrectly putting part of the path in the template
      # name instead of the prefix.
      def normalize_name(name, prefixes) #:nodoc:
        name  = name.to_s.gsub(handlers_regexp, '')
        parts = name.split('/')
        name  = parts.pop

        prefixes = if prefixes.blank?
          [parts.join('/')]
        else
          prefixes.map { |prefix| [prefix, *parts].compact.join('/') }
        end

        return name, prefixes
      end

      def default_handlers #:nodoc:
        @@default_handlers ||= Template::Handlers.extensions
      end

      def handlers_regexp #:nodoc:
        @@handlers_regexp ||= /\.(?:#{default_handlers.join('|')})$/
      end
    end

    module Details
      attr_accessor :cache

      # Calculate the details key. Remove the handlers from calculation to improve performance
      # since the user cannot modify it explicitly.
      def details_key #:nodoc:
        @details_key ||= DetailsKey.get(@details) if @cache
      end

      # Temporary skip passing the details_key forward.
      def disable_cache
        old_value, @cache = @cache, false
        yield
      ensure
        @cache = old_value
      end

      # Freeze the current formats in the lookup context. By freezing them, you are guaranteeing
      # that next template lookups are not going to modify the formats. The controller can also
      # use this, to ensure that formats won't be further modified (as it does in respond_to blocks).
      def freeze_formats(formats, unless_frozen=false) #:nodoc:
        return if unless_frozen && @frozen_formats
        self.formats = formats
        @frozen_formats = true
      end

      # Overload formats= to expand ["*/*"] values and automatically
      # add :html as fallback to :js.
      def formats=(values)
        if values
          values.concat(_formats_defaults) if values.delete "*/*"
          values << :html if values == [:js]
        end
        super(values)
      end

      # Do not use the default locale on template lookup.
      def skip_default_locale!
        @skip_default_locale = true
        self.locale = nil
      end

      # Overload locale to return a symbol instead of array.
      def locale
        @details[:locale].first
      end

      # Overload locale= to also set the I18n.locale. If the current I18n.config object responds
      # to original_config, it means that it's has a copy of the original I18n configuration and it's
      # acting as proxy, which we need to skip.
      def locale=(value)
        if value
          config = I18n.config.respond_to?(:original_config) ? I18n.config.original_config : I18n.config
          config.locale = value
        end

        super(@skip_default_locale ? I18n.locale : _locale_defaults)
      end

      # A method which only uses the first format in the formats array for layout lookup.
      # This method plays straight with instance variables for performance reasons.
      def with_layout_format
        if formats.size == 1
          yield
        else
          old_formats = formats
          _set_detail(:formats, formats[0,1])

          begin
            yield
          ensure
            _set_detail(:formats, old_formats)
          end
        end
      end

      # Update the details keys by merging the given hash into the current
      # details hash. If a block is given, the details are modified just during
      # the execution of the block and reverted to the previous value after.
      def update_details(new_details)
        old_details = @details.dup

        registered_detail_setters.each do |key, setter|
          send(setter, new_details[key]) if new_details.key?(key)
        end

        begin
          yield
        ensure
          @details_key = nil
          @details = old_details
        end
      end

    protected

      def _set_detail(key, value)
        @details_key = nil
        @details = @details.dup if @details.frozen?
        @details[key] = value.freeze
      end
    end

    include Accessors
    include Details
    include ViewPaths
  end
end

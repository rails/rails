module ActionView
  class AbstractRenderer #:nodoc:
    delegate :find_template, :template_exists?, :with_fallbacks, :update_details,
      :with_layout_format, :formats, :to => :@lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render
      raise NotImplementedError
    end

    protected
    
    def extract_details(options)
      details = {}
      @lookup_context.registered_details.each do |key|
        next unless value = options[key]
        details[key] = Array.wrap(value)
      end
      details
    end
    
    def extract_format(value, details)
      if value.is_a?(String) && value.sub!(formats_regexp, "")
        ActiveSupport::Deprecation.warn "Passing the format in the template name is deprecated. " \
          "Please pass render with :formats => [:#{$1}] instead.", caller
        details[:formats] ||= [$1.to_sym]
      end
    end

    def formats_regexp
      @@formats_regexp ||= /\.(#{Mime::SET.symbols.join('|')})$/
    end

    def instrument(name, options={})
      ActiveSupport::Notifications.instrument("render_#{name}.action_view", options){ yield }
    end

    def prepend_formats(formats)
      formats = Array(formats)
      return if formats.empty? || @lookup_context.html_fallback_for_js
      @lookup_context.formats = formats | @lookup_context.formats
    end
  end
end

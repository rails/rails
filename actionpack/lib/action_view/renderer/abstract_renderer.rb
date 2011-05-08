module ActionView
  class AbstractRenderer #:nodoc:
    delegate :find_template, :template_exists?, :with_fallbacks, :update_details,
      :with_layout_format, :formats, :freeze_formats, :to => :@lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render
      raise NotImplementedError
    end

    # Checks if the given path contains a format and if so, change
    # the lookup context to take this new format into account.
    def wrap_formats(value)
      return yield unless value.is_a?(String)

      if value.sub!(formats_regexp, "")
        update_details(:formats => [$1.to_sym]){ yield }
      else
        yield
      end
    end

    def formats_regexp
      @@formats_regexp ||= /\.(#{Mime::SET.symbols.join('|')})$/
    end

    protected

    def instrument(name, options={})
      ActiveSupport::Notifications.instrument("render_#{name}.action_view", options){ yield }
    end
  end
end

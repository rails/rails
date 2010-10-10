module ActionView
  class AbstractRenderer #:nodoc:
    attr_reader :vew, :lookup_context

    delegate :find_template, :template_exists?, :with_fallbacks, :update_details,
      :with_layout_format, :formats, :to => :lookup_context

    def initialize(view)
      @view = view
      @lookup_context = view.lookup_context
    end

    def render
      raise NotImplementedError
    end

    # Contains the logic that actually renders the layout.
    def render_layout(layout, locals, &block) #:nodoc:
      view = @view
      layout.render(view, locals){ |*name| view._layout_for(*name, &block) }
    end

    # Checks if the given path contains a format and if so, change
    # the lookup context to take this new format into account.
    def wrap_formats(value)
      return yield unless value.is_a?(String)
      @@formats_regexp ||= /\.(#{Mime::SET.symbols.join('|')})$/

      if value.sub!(@@formats_regexp, "")
        update_details(:formats => [$1.to_sym]){ yield }
      else
        yield
      end
    end
  end
end
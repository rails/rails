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
        details[key] = Array(value)
      end
      details
    end

    def instrument(name, options={})
      ActiveSupport::Notifications.instrument("render_#{name}.action_view", options){ yield }
    end
  end
end

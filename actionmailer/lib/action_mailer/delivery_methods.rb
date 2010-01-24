module ActionMailer
  # This modules makes a DSL for adding delivery methods to ActionMailer
  module DeliveryMethods
    # TODO Make me class inheritable
    def delivery_settings
      @@delivery_settings ||= Hash.new { |h,k| h[k] = {} }
    end

    def delivery_methods
      @@delivery_methods ||= {}
    end

    def delivery_method=(method)
      raise ArgumentError, "Unknown delivery method #{method.inspect}" unless delivery_methods[method]
      @delivery_method = method
    end

    def add_delivery_method(symbol, klass, default_options={})
      self.delivery_methods[symbol]  = klass
      self.delivery_settings[symbol] = default_options
    end

    def wrap_delivery_behavior(mail, method=nil)
      method ||= delivery_method

      mail.register_for_delivery_notification(self)

      if method.is_a?(Symbol)
        mail.delivery_method(delivery_methods[method],
                             delivery_settings[method])
      else
        mail.delivery_method(method)
      end

      mail.perform_deliveries    = perform_deliveries
      mail.raise_delivery_errors = raise_delivery_errors
    end


    def respond_to?(method_symbol, include_private = false) #:nodoc:
      matches_settings_method?(method_symbol) || super
    end

  protected

    # TODO Get rid of this method missing magic
    def method_missing(method_symbol, *parameters) #:nodoc:
      if match = matches_settings_method?(method_symbol)
        if match[2]
          delivery_settings[match[1].to_sym] = parameters[0]
        else
          delivery_settings[match[1].to_sym]
        end
      else
        super
      end
    end

    def matches_settings_method?(method_name) #:nodoc:
      /(#{delivery_methods.keys.join('|')})_settings(=)?$/.match(method_name.to_s)
    end
  end
end
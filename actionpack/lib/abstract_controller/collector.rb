require "action_dispatch/http/mime_type"

module AbstractController
  module Collector
    def self.generate_method_for_mime(mime)
      sym = mime.is_a?(Symbol) ? mime : mime.to_sym
      const = sym.upcase
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{sym}(*args, &block)                # def html(*args, &block)
          custom(Mime::#{const}, *args, &block)  #   custom(Mime::HTML, *args, &block)
        end                                      # end
      RUBY
    end

    Mime::SET.each do |mime|
      generate_method_for_mime(mime)
    end

    Mime::Type.register_callback do |mime|
      generate_method_for_mime(mime) unless self.instance_methods.include?(mime.to_sym)
    end

  protected

    def method_missing(symbol, &block)
      const_name = symbol.upcase

      unless Mime.const_defined?(const_name)
        raise NoMethodError, "To respond to a custom format, register it as a MIME type first: " \
          "http://guides.rubyonrails.org/action_controller_overview.html#restful-downloads. " \
          "If you meant to respond to a variant like :tablet or :phone, not a custom format, " \
          "be sure to nest your variant response within a format response: " \
          "format.html { |html| html.tablet { ... } }"
      end

      mime_constant = Mime.const_get(const_name)

      if Mime::SET.include?(mime_constant)
        AbstractController::Collector.generate_method_for_mime(mime_constant)
        send(symbol, &block)
      else
        super
      end
    end
  end
end

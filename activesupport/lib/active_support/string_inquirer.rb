# frozen_string_literal: true

module ActiveSupport
  # Wrapping a string in this class gives you a prettier way to test
  # for equality. The value returned by <tt>Rails.env</tt> is wrapped
  # in a StringInquirer object, so instead of calling this:
  #
  #   Rails.env == 'production'
  #
  # you can call this:
  #
  #   Rails.env.production?
  #
  # == Instantiating a new StringInquirer
  #
  #   vehicle = ActiveSupport::StringInquirer.new('car')
  #   vehicle.car?   # => true
  #   vehicle.bike?  # => false
  class StringInquirer
    def initialize(method_name)
      @method_name = method_name

      self.class.send(:define_method, "#{method_name}?") { true }
    end

    private
      def respond_to_missing?(method_name, include_private = false)
        method_name.end_with?("?") || super
      end

      def method_missing(method_name, *arguments)
        method_name.end_with?("?") ? false : super
      end
  end
end

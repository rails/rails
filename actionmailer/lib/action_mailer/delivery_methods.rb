module ActionMailer
  # This modules makes a DSL for adding delivery methods to ActionMailer
  module DeliveryMethods
    extend ActiveSupport::Concern

    included do
      add_delivery_method :smtp, Mail::SMTP,
        :address              => "localhost",
        :port                 => 25,
        :domain               => 'localhost.localdomain',
        :user_name            => nil,
        :password             => nil,
        :authentication       => nil,
        :enable_starttls_auto => true

      add_delivery_method :file, Mail::FileDelivery,
        :location => defined?(Rails.root) ? "#{Rails.root}/tmp/mails" : "#{Dir.tmpdir}/mails"

      add_delivery_method :sendmail, Mail::Sendmail,
        :location   => '/usr/sbin/sendmail',
        :arguments  => '-i -t'

      add_delivery_method :test, Mail::TestMailer

      superclass_delegating_reader :delivery_method
      self.delivery_method = :smtp
    end

    module ClassMethods
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

      def respond_to?(method_symbol, include_private = false) #:nodoc:
        matches_settings_method?(method_symbol) || super
      end

    protected

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
end
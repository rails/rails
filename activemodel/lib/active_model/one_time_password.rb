module ActiveModel
  module OneTimePassword
    extend ActiveSupport::Concern

    module ClassMethods
      def has_one_time_password
        begin
          require 'rotp'
        rescue LoadError
          $stderr.puts "You don't have rotp installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        include InstanceMethodsOnActivation

        before_create { self.otp_secret_key = ROTP::Base32.random_base32 }

        if respond_to?(:attributes_protected_by_default)
          def self.attributes_protected_by_default #:nodoc:
            super + ['otp_secret_key']
          end
        end
      end
    end

    module InstanceMethodsOnActivation
      def authenticate_otp(code, options = {})
        totp = ROTP::TOTP.new(self.otp_secret_key)

        if drift = options[:drift]
          totp.verify_with_drift(code, drift)
        else
          totp.verify(code)
        end
      end

      def otp_code(time = Time.now)
        ROTP::TOTP.new(self.otp_secret_key).at(time)
      end

      def provisioning_uri(account = nil)
        account ||= self.email if self.respond_to?(:email)
        ROTP::TOTP.new(self.otp_secret_key).provisioning_uri(account)
      end
    end
  end
end

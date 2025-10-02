# frozen_string_literal: true

module ActiveRecord
  module SecureToken
    class MinimumLengthError < StandardError; end

    MINIMUM_TOKEN_LENGTH = 24

    extend ActiveSupport::Concern

    module ClassMethods
      # Example using #has_secure_token
      #
      #   # Schema: User(token:string, auth_token:string)
      #   class User < ActiveRecord::Base
      #     has_secure_token
      #     has_secure_token :auth_token, length: 36
      #   end
      #
      #   user = User.new
      #   user.save
      #   user.token # => "pX27zsMN2ViQKta1bGfLmVJE"
      #   user.auth_token # => "tU9bLuZseefXQ4yQxQo8wjtBvsAfPc78os6R"
      #   user.regenerate_token # => true
      #   user.regenerate_auth_token # => true
      #
      # +SecureRandom::base58+ is used to generate at minimum a 24-character unique token, so collisions are highly unlikely.
      #
      # Note that it's still possible to generate a race condition in the database in the same way that
      # {validates_uniqueness_of}[rdoc-ref:Validations::ClassMethods#validates_uniqueness_of] can.
      # You're encouraged to add a unique index in the database to deal with this even more unlikely scenario.
      #
      # ==== Options
      #
      # [+:length+]
      #   Length of the Secure Random, with a minimum of 24 characters. It will
      #   default to 24.
      #
      # [+:on+]
      #   The callback when the value is generated. When called with <tt>on:
      #   :initialize</tt>, the value is generated in an
      #   <tt>after_initialize</tt> callback, otherwise the value will be used
      #   in a <tt>before_</tt> callback. When not specified, +:on+ will use the value of
      #   <tt>config.active_record.generate_secure_token_on</tt>, which defaults to +:initialize+
      #   starting in \Rails 7.1.
      def has_secure_token(attribute = :token, length: MINIMUM_TOKEN_LENGTH, on: ActiveRecord.generate_secure_token_on)
        if length < MINIMUM_TOKEN_LENGTH
          raise MinimumLengthError, "Token requires a minimum length of #{MINIMUM_TOKEN_LENGTH} characters."
        end

        # Load securerandom only when has_secure_token is used.
        require "active_support/core_ext/securerandom"
        define_method("regenerate_#{attribute}") { update! attribute => self.class.generate_unique_secure_token(length: length) }
        set_callback on, on == :initialize ? :after : :before do
          if new_record? && !query_attribute(attribute)
            send("#{attribute}=", self.class.generate_unique_secure_token(length: length))
          end
        end
      end

      def generate_unique_secure_token(length: MINIMUM_TOKEN_LENGTH)
        SecureRandom.base58(length)
      end
    end
  end
end

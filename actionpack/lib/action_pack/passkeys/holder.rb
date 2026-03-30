# frozen_string_literal: true

module ActionPack
  # = Action Pack Passkey Holder
  #
  # Adds passkey support to an Active Record model (the "holder" of passkeys).
  #
  # == Usage
  #
  #   class User < ApplicationRecord
  #     has_passkeys name: :email_address, display_name: :name
  #   end
  #
  # This sets up a polymorphic +has_many :passkeys+ association and defines two methods on the
  # model that supply holder-specific options for the WebAuthn ceremonies:
  #
  # * +passkey_registration_options+ — merged into ActionPack::Passkeys::Passkey.registration_options
  # * +passkey_authentication_options+ — merged into ActionPack::Passkeys::Passkey.authentication_options
  #
  # == Options
  #
  # +has_passkeys+ accepts keyword arguments that map to WebAuthn creation or request option
  # fields. Values can be symbols (sent to the record), procs (evaluated in the record's context),
  # or plain values:
  #
  # [+name+]
  #   A human-readable account identifier (typically an email or username) shown by the
  #   authenticator when the user selects a passkey. Maps to the WebAuthn +user.name+ field.
  #
  # [+display_name+]
  #   A friendly label for the user (typically their full name) shown by the authenticator
  #   during passkey registration. Maps to the WebAuthn +user.displayName+ field.
  #
  #   has_passkeys name: :email, display_name: :name
  #
  # For more complex configuration, pass a block that receives an ActionPack::Passkeys::Passkeys::Holder::Config:
  #
  #   has_passkeys do |config|
  #     config.registration_options { { name: email, display_name: name } }
  #     config.authentication_options  { { user_verification: "required" } }
  #   end
  module Passkeys::Holder
    extend ActiveSupport::Concern

    class_methods do
      # Declares that this model can hold passkeys. Sets up a polymorphic +has_many+ association
      # and defines +passkey_registration_options+ and +passkey_authentication_options+ instance methods used
      # by ActionPack::Passkeys::Passkey to build ceremony options.
      #
      # Keyword arguments matching CreationOptions or RequestOptions fields are extracted and
      # turned into holder-scoped option procs automatically. An optional block yields a Config
      # for more complex setup.
      def has_passkeys(**options, &block)
        config = Config.new(**options)
        block&.call(config)

        has_many config.association_name,
          as: :holder,
          dependent: config.dependent,
          class_name: "ActionPack::Passkeys::Passkey"

        define_method(:passkey_registration_options) do
          {
            id: id,
            exclude_credentials: public_send(config.association_name)
          }.merge(config.evaluate_registration_options(self))
        end

        define_method(:passkey_authentication_options) do
          { credentials: public_send(config.association_name) }.merge(config.evaluate_authentication_options(self))
        end
      end
    end

    # Configuration object yielded by +has_passkeys+ when a block is given. Allows setting
    # custom association options and ceremony option blocks.
    class Config
      attr_accessor :association_name, :dependent

      def initialize(**options) # :nodoc:
        @association_name = options.delete(:association_name) || :passkeys
        @dependent = options.delete(:dependent) || :destroy

        if creation_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::CreationOptions, options)
          @registration_options = options_to_proc(creation_opts)
        end

        if request_opts = extract_options_for(ActionPack::WebAuthn::PublicKeyCredential::RequestOptions, options)
          @authentication_options = options_to_proc(request_opts)
        end
      end

      # Sets a block to evaluate in the holder's context to produce additional authentication options.
      #
      #   config.authentication_options { { user_verification: "required" } }
      def authentication_options(&block)
        @authentication_options = block
      end

      # Sets a block to evaluate in the holder's context to produce additional registration options.
      #
      #   config.registration_options { { name: email, display_name: name } }
      def registration_options(&block)
        @registration_options = block
      end

      def evaluate_authentication_options(record) # :nodoc:
        if @authentication_options
          record.instance_exec(&@authentication_options)
        else
          {}
        end
      end

      def evaluate_registration_options(record) # :nodoc:
        if @registration_options
          record.instance_exec(&@registration_options)
        else
          {}
        end
      end

      private
        def extract_options_for(klass, options)
          keys = klass.attribute_names.map(&:to_sym)

          extracted = options.slice(*keys)
          options.except!(*keys)
          extracted if extracted.any?
        end

        def options_to_proc(options)
          proc do
            options.transform_values do |value|
              case value
              when Symbol then send(value)
              when Proc then instance_exec(&value)
              else value
              end
            end
          end
        end
    end
  end
end

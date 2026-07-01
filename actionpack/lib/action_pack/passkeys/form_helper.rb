# frozen_string_literal: true

module ActionPack
  # = Action Pack Passkey Form Helper
  #
  # View helpers for rendering passkey registration and sign-in buttons.
  module Passkeys::FormHelper
    # Renders a button for registering a new passkey. Accepts a +label+ string or a block
    # for button content.
    #
    # Options:
    # - +options+ - WebAuthn creation options (JSON-serializable hash).
    # - +challenge_url+ - Endpoint to refresh the challenge nonce.
    # - +wrapper+ - HTML attributes for the outer web component element.
    # - +form+ - Additional HTML attributes for the +<form>+ tag. Supports a +:param+ key
    #   to set the form parameter namespace (default: +:passkey+).
    # - +error+ - HTML attributes for the error message +<div>+. Supports a +:message+ key
    #   to override the default error text.
    # - +cancellation+ - HTML attributes for the cancellation message +<div>+. Supports a
    #   +:message+ key to override the default cancellation text.
    # - All other options are passed to the +<button>+ tag.
    def passkey_registration_button(name = nil, url = nil, **options, &block)
      url, name = name, block ? capture(&block) : nil if block_given?
      component_options, form_options, button_options, error_options = partition_passkey_options(url, options)
      error_options[:error][:message] ||= I18n.t("helpers.passkeys.registration.error", default: "Something went wrong while registering your passkey.")
      error_options[:cancellation][:message] ||= I18n.t("helpers.passkeys.registration.cancelled", default: "Passkey registration was cancelled. Try again when you are ready.")
      error_options[:duplicate][:message] ||= I18n.t("helpers.passkeys.registration.duplicate", default: "You already have a passkey registered on this device. Remove the existing one first and try again.")
      param = form_options.delete(:param)

      content_tag("rails-passkey-registration-button", **component_options.transform_keys { |key| key.to_s.dasherize }) do
        tag.form(**form_options) do
          hidden_field_tag(:authenticity_token, form_authenticity_token) +
            hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
            hidden_field_tag("#{param}[attestation_object]", nil, id: nil, data: { passkey_field: "attestation_object" }) +
            hidden_field_tag("#{param}[transports][]", nil, id: nil, data: { passkey_field: "transports" }) +
            tag.button(name, type: :button, data: { passkey: "register" }, **button_options)
        end + passkey_error_messages(**error_options)
      end
    end

    # Renders a button for signing in with a passkey. Accepts a +label+ string or a block
    # for button content.
    #
    # Options:
    # - +options+ - WebAuthn request options (JSON-serializable hash).
    # - +challenge_url+ - Endpoint to refresh the challenge nonce.
    # - +mediation+ - WebAuthn mediation hint (e.g. +"conditional"+ for autofill-assisted sign in).
    # - +wrapper+ - HTML attributes for the outer web component element.
    # - +form+ - Additional HTML attributes for the +<form>+ tag. Supports a +:param+ key
    #   to set the form parameter namespace (default: +:passkey+).
    # - +error+ - HTML attributes for the error message +<div>+. Supports a +:message+ key
    #   to override the default error text.
    # - +cancellation+ - HTML attributes for the cancellation message +<div>+. Supports a
    #   +:message+ key to override the default cancellation text.
    # - All other options are passed to the +<button>+ tag.
    def passkey_sign_in_button(name = nil, url = nil, **options, &block)
      url, name = name, block ? capture(&block) : nil if block_given?
      component_options, form_options, button_options, error_options = partition_passkey_options(url, options)
      error_options[:error][:message] ||= I18n.t("helpers.passkeys.sign_in.error", default: "Something went wrong while signing in with your passkey.")
      error_options[:cancellation][:message] ||= I18n.t("helpers.passkeys.sign_in.cancelled", default: "Passkey sign in was cancelled. Try again when you are ready.")
      param = form_options.delete(:param)

      content_tag("rails-passkey-sign-in-button", **component_options.transform_keys { |key| key.to_s.dasherize }) do
        tag.form(**form_options) do
          hidden_field_tag(:authenticity_token, form_authenticity_token) +
            hidden_field_tag("#{param}[id]", nil, id: nil, data: { passkey_field: "id" }) +
            hidden_field_tag("#{param}[client_data_json]", nil, id: nil, data: { passkey_field: "client_data_json" }) +
            hidden_field_tag("#{param}[authenticator_data]", nil, id: nil, data: { passkey_field: "authenticator_data" }) +
            hidden_field_tag("#{param}[signature]", nil, id: nil, data: { passkey_field: "signature" }) +
            tag.button(name, type: :button, data: { passkey: "sign_in" }, **button_options)
        end + passkey_error_messages(**error_options)
      end
    end

    private
      def partition_passkey_options(url, options)
        passkey_options = options.fetch(:options, {})
        wrapper_options = options.fetch(:wrapper, {})

        component_options = options
          .slice(:challenge_url, :mediation)
          .reverse_merge(challenge_url: default_passkey_challenge_url, options: passkey_options.to_json(except: :challenge))

        form_options = options
          .fetch(:form, {})
          .reverse_merge(method: :post, action: url, class: "button_to", param: :passkey)

        error_options = options.slice(:error, :cancellation, :duplicate).reverse_merge(error: {}, cancellation: {}, duplicate: {})

        button_options = options.except(:options, :form, :wrapper, *component_options.keys, *error_options.keys)

        [ wrapper_options.merge(component_options), form_options, button_options, error_options ]
      end

      def default_passkey_challenge_url
        if challenge_url = ActionPack::Passkeys.challenge_url
          instance_exec(&challenge_url)
        else
          passkey_challenge_path
        end
      end

      def passkey_error_messages(error: {}, cancellation: {}, duplicate: {})
        error_message, error_attributes = build_passkey_error_options("error", error)
        cancellation_message, cancellation_attributes = build_passkey_error_options("cancelled", cancellation)

        messages = tag.div(error_message, hidden: true, **error_attributes) +
          tag.div(cancellation_message, hidden: true, **cancellation_attributes)

        if duplicate[:message]
          duplicate_message, duplicate_attributes = build_passkey_error_options("duplicate", duplicate)
          messages += tag.div(duplicate_message, hidden: true, **duplicate_attributes)
        end

        messages
      end

      def build_passkey_error_options(type, options)
        message = options[:message]

        attributes = options.except(:message)
        attributes[:data] ||= {}
        attributes[:data][:passkey_error] = type

        [ message, attributes ]
      end
  end
end

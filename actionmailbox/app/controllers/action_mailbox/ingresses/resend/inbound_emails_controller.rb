# frozen_string_literal: true

require "base64"
require "json"
require "mail"
require "net/http"
require "openssl"
require "uri"

module ActionMailbox::Ingresses
  module Resend
    # Controller to handle inbound email webhooks from Resend.
    # Mirrors the standalone actionmailbox-resend behavior: verifies Svix signatures,
    # validates request size, checks idempotency, fetches full email/attachments from Resend API when needed,
    # and builds RFC822 messages for Action Mailbox.
    class InboundEmailsController < ActionMailbox::BaseController
      MAX_REQUEST_SIZE = 10.megabytes
      MAX_ATTACHMENT_SIZE = 25.megabytes
      ALLOWED_HOST_PATTERN = /\A[a-z0-9-]+\.resend\.(com|app)\z/i

      before_action :authenticate
      before_action :validate_request_size
      before_action :check_idempotency
      param_encoding :create, :_json, Encoding::ASCII_8BIT

      def create
        return head :ok unless payload["type"] == "email.received"
        return head :unprocessable_entity if email_id.blank? && raw_email_b64.blank?

        ActionMailbox::InboundEmail.create_and_extract_message_id! normalized_email
        mark_processed
        head :no_content
      rescue JSON::ParserError => error
        logger.error("Resend webhook: Invalid JSON - #{error.message}")
        head :bad_request
      rescue KeyError => error
        logger.error error.message
        head ActionDispatch::Constants::UNPROCESSABLE_CONTENT
      rescue StandardError => error
        logger.error("Resend webhook error: #{error.message}")
        head :internal_server_error
      end

      private
        def validate_request_size
          return if request.content_length.nil?
          return unless request.content_length > MAX_REQUEST_SIZE

          logger.warn("Resend webhook rejected: request too large (#{request.content_length} bytes)")
          head :payload_too_large
        end

        def check_idempotency
          return if svix_id.blank?
          return unless already_processed?

          logger.info("Resend webhook skipped: duplicate svix-id #{svix_id}")
          head :conflict
        end

        def already_processed?
          Rails.cache.read(cache_key).present?
        end

        def mark_processed
          return if svix_id.blank?
          Rails.cache.write(cache_key, true, expires_in: 24.hours)
        end

        def cache_key
          "resend:webhook:#{svix_id}"
        end

        def svix_id
          request.headers["svix-id"]
        end

        def authenticate
          head :unauthorized unless authenticated?
        end

        def authenticated?
          if signing_secret.present?
            Authenticator.new(signing_secret: signing_secret, headers: request.headers, payload: request.raw_post).authenticated?
          else
            raise ArgumentError, <<~MESSAGE.squish
              Missing required Resend webhook signing secret. Set action_mailbox.resend_signing_secret in your application's
              encrypted credentials or provide the RESEND_WEBHOOK_SECRET environment variable.
            MESSAGE
          end
        end

        def signing_secret
          Rails.application.credentials.dig(:action_mailbox, :resend_signing_secret) || ENV["RESEND_WEBHOOK_SECRET"]
        end

        def raw_email
          decoded_email.tap do |raw_email|
            original_to = Array.wrap(payload.dig("data", "email", "to") || payload.dig("data", "object", "to") || payload["to"]).first
            raw_email.prepend("X-Original-To: ", original_to, "\n") if original_to.present?
          end
        end

        def decoded_email
          if raw_email_b64.present?
            Base64.decode64(raw_email_b64).presence || raise(KeyError, "Missing raw email")
          else
            build_mime_from_resend_api || raise(KeyError, "Missing raw email")
          end
        end

        def raw_email_b64
          payload.dig("data", "email", "raw") || payload.dig("data", "object", "raw") || payload["raw"]
        end

        def email_id
          payload.dig("data", "email_id") || payload.dig("data", "id")
        end

        def payload
          @payload ||= JSON.parse(request.raw_post)
        end

        def normalized_email
          mail = Mail.new(raw_email)
          normalize_mail_for_display(mail).encoded
        rescue StandardError => error
          logger.warn("Resend webhook: Failed to normalize email structure - #{error.message}")
          raw_email
        end

        def normalize_mail_for_display(mail)
          mixed = Mail.new
          mixed.subject = mail.subject
          mixed.from = mail.from
          mixed.to = mail.to
          mixed.cc = mail.cc
          mixed.bcc = mail.bcc
          mixed.content_type = "multipart/mixed"

          related = Mail::Part.new
          related.content_type = "multipart/related"

          alt = Mail::Part.new
          alt.content_type = "multipart/alternative"
          if mail.multipart?
            alt.add_part(mail.text_part) if mail.text_part
            alt.add_part(mail.html_part) if mail.html_part
          else
            alt.add_part(Mail::Part.new { body mail.decoded; content_type mail.content_type })
          end
          related.add_part(alt)

          mail.attachments.each do |att|
            if att.inline?
              related.attachments[att.filename] = {
                content_type: att.content_type,
                content: att.body.decoded,
                content_id: att.cid
              }
            else
              mixed.attachments[att.filename] = {
                content_type: att.content_type,
                content: att.body.decoded
              }
            end
          end

          mixed.add_part(related)
          mixed
        end

        def build_mime_from_resend_api
          return if resend_api_key.blank? || email_id.blank?

          email_data = fetch_email(email_id)
          return if email_data.nil?

          mail = Mail.new
          set_mail_headers(mail, email_data)

          has_attachments = email_data["attachments"].present?
          if has_attachments && email_data["html"].present?
            email_data["html"] = convert_data_uris_to_cid(email_data["html"], email_data["attachments"], email_id)
          end

          set_mail_body(mail, email_data)
          add_all_attachments(mail, email_data) if has_attachments

          mail.to_s
        end

        def set_mail_headers(mail, email_data)
          mail.from = email_data["from"]
          mail.to = email_data["to"]
          mail.cc = email_data["cc"] if email_data["cc"].present?
          mail.bcc = email_data["bcc"] if email_data["bcc"].present?
          mail.subject = email_data["subject"] || "(no subject)"
          mail.message_id = email_data["message_id"] if email_data["message_id"].present?
          mail.in_reply_to = email_data.dig("headers", "in-reply-to") if email_data.dig("headers", "in-reply-to").present?
          mail.references = email_data.dig("headers", "references") if email_data.dig("headers", "references").present?
        end

        def set_mail_body(mail, email_data)
          if email_data["text"].present? && email_data["html"].present?
            mail.text_part = Mail::Part.new do
              content_type "text/plain; charset=UTF-8"
              body email_data["text"]
            end
            mail.html_part = Mail::Part.new do
              content_type "text/html; charset=UTF-8"
              body email_data["html"]
            end
          elsif email_data["html"].present?
            mail.content_type = "text/html; charset=UTF-8"
            mail.body = email_data["html"]
          else
            mail.content_type = "text/plain; charset=UTF-8"
            mail.body = email_data["text"] || "(no body)"
          end
        end

        def add_all_attachments(mail, email_data)
          email_data["attachments"].each do |attachment_meta|
            content = fetch_attachment(email_id, attachment_meta["id"])
            next if content.nil?

            if attachment_meta["content_disposition"] == "inline"
              mail.attachments.inline[attachment_meta["filename"]] = {
                content_type: attachment_meta["content_type"],
                content: content
              }
              if attachment_meta["content_id"].present?
                mail.attachments.last.content_id = attachment_meta["content_id"].gsub(/[<>]/, "")
              end
            else
              mail.attachments[attachment_meta["filename"]] = {
                content_type: attachment_meta["content_type"],
                content: content
              }
            end
          end
        end

        def fetch_email(id)
          uri = URI("https://api.resend.com/emails/receiving/#{id}")
          response = http_get(uri)
          JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
        rescue JSON::ParserError, StandardError => error
          logger.error("Resend API fetch failed: #{error.message}")
          nil
        end

        def fetch_attachment(email_id, attachment_id)
          return if resend_api_key.blank?

          metadata_uri = URI("https://api.resend.com/emails/receiving/#{email_id}/attachments/#{attachment_id}")
          metadata_response = http_get(metadata_uri)
          return unless metadata_response.is_a?(Net::HTTPSuccess)

          metadata = JSON.parse(metadata_response.body)
          download_url = metadata["download_url"]
          return if download_url.blank?
          return unless valid_resend_url?(download_url)

          download_uri = URI(download_url)

          head_response = http_head(download_uri)
          if head_response["content-length"].present?
            size = head_response["content-length"].to_i
            return if size > MAX_ATTACHMENT_SIZE
          end

          download_response = http_get(download_uri, follow_redirects: false)
          download_response.body if download_response.is_a?(Net::HTTPSuccess)
        rescue JSON::ParserError, StandardError => error
          logger.error("Resend attachment fetch failed: #{error.message}")
          nil
        end

        def convert_data_uris_to_cid(html, attachments, email_id)
          return html if html.blank? || attachments.blank?

          inline_attachments = attachments.select { |a| a["content_disposition"] == "inline" && a["content_id"].present? }
          return html unless inline_attachments.any?

          data_uri_to_cid = build_data_uri_map(inline_attachments, email_id)

          html.gsub(%r{(<img[^>]+src=")data:image/[^;]+;base64,([^"]+)("[^>]*>)}i) do |match|
            prefix = ::Regexp.last_match(1)
            base64_data = ::Regexp.last_match(2)
            suffix = ::Regexp.last_match(3)

            content_id = data_uri_to_cid[base64_data]
            content_id ? "#{prefix}cid:#{content_id}#{suffix}" : match
          end
        rescue StandardError => error
          logger.error("Failed to convert data URIs to cid references: #{error.message}")
          html
        end

        def build_data_uri_map(inline_attachments, email_id)
          map = {}
          inline_attachments.each do |attachment|
            content = fetch_attachment(email_id, attachment["id"])
            next if content.nil?
            base64_content = Base64.strict_encode64(content)
            content_id = attachment["content_id"].gsub(/[<>]/, "")
            map[base64_content] = content_id
          end
          map
        end

        def valid_resend_url?(url)
          uri = URI.parse(url)
          return false unless uri.scheme == "https"
          return false unless uri.host&.match?(ALLOWED_HOST_PATTERN)
          true
        rescue URI::InvalidURIError
          false
        end

        def resend_api_key
          ENV["RESEND_API_KEY"]
        end

        def http_get(uri, follow_redirects: true)
          Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https",
            cert_store: default_cert_store,
            open_timeout: 5,
            read_timeout: 10
          ) do |http|
            request = Net::HTTP::Get.new(uri)
            request["Authorization"] = "Bearer #{resend_api_key}"
            request["Content-Type"] = "application/json"
            response = http.request(request)
            return response if follow_redirects
            return response unless response.is_a?(Net::HTTPRedirection)
            response
          end
        end

        def http_head(uri)
          Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https",
            cert_store: default_cert_store,
            open_timeout: 5,
            read_timeout: 10
          ) do |http|
            request = Net::HTTP::Head.new(uri)
            request["Authorization"] = "Bearer #{resend_api_key}"
            http.request(request)
          end
        end

        # Disable CRL checking for OpenSSL 3.x while keeping certificate verification.
        def default_cert_store
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          store.flags = 0
          store
        end

        class Authenticator
          attr_reader :secret, :headers, :payload

          def initialize(signing_secret:, headers:, payload:)
            @secret = signing_secret
            @headers = headers
            @payload = payload
          end

          def authenticated?
            signed? && recent?
          rescue ArgumentError, TypeError
            false
          end

          private
            def signed?
              provided_signatures.any? do |signed|
                ActiveSupport::SecurityUtils.secure_compare(signed, expected_signature) ||
                  ActiveSupport::SecurityUtils.secure_compare(signed, "v1,#{expected_signature}")
              end
            end

            def recent?
              Time.at(Integer(timestamp)) >= 5.minutes.ago
            end

            def provided_signatures
              signature.to_s.split
            end

            def signature
              headers["HTTP_SVIX_SIGNATURE"]
            end

            def timestamp
              headers["HTTP_SVIX_TIMESTAMP"]
            end

            def id
              headers["HTTP_SVIX_ID"]
            end

            def expected_signature
              key = Base64.decode64(secret.to_s.delete_prefix("whsec_"))
              signed_payload = [id, timestamp, payload].join(".")
              Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", key, signed_payload))
            end
        end
    end
  end
end

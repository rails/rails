# frozen_string_literal: true

require "active_support/core_ext/array/access"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/output_safety"
require "action_view/helpers/tag_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View URL \Helpers
    #
    # Provides a set of methods for getting URLs that
    # depend on the routing subsystem (see ActionDispatch::Routing).
    module UrlHelper
      # This helper may be included in any class that includes the
      # URL helpers of a routes (routes.url_helpers).
      extend ActiveSupport::Concern

      module ClassMethods
        def _url_for_modules
          ActionView::RoutingUrlFor
        end
      end

      # Basic implementation of url_for to allow use helpers without routes existence
      def url_for(options = nil) # :nodoc:
        case options
        when String
          options
        when :back
          _back_url
        else
          raise ArgumentError, "arguments passed to url_for can't be handled. Please require " \
                               "routes or provide your own implementation"
        end
      end

      def _back_url # :nodoc:
        _filtered_referrer || "javascript:history.back()"
      end
      private :_back_url

      def _filtered_referrer # :nodoc:
        if controller.respond_to?(:request)
          referrer = controller.request.env["HTTP_REFERER"]
          if referrer && URI(referrer).scheme != "javascript"
            referrer
          end
        end
      rescue URI::InvalidURIError
      end
      private :_filtered_referrer

      # Creates a mailto link tag to the specified +email_address+, which is
      # also used as the name of the link unless +name+ is specified. Additional
      # HTML attributes for the link can be passed in +html_options+.
      #
      # +mail_to+ has several methods for customizing the email itself by
      # passing special keys to +html_options+.
      #
      # ==== Options
      # * <tt>:subject</tt> - Preset the subject line of the email.
      # * <tt>:body</tt> - Preset the body of the email.
      # * <tt>:cc</tt> - Carbon Copy additional recipients on the email.
      # * <tt>:bcc</tt> - Blind Carbon Copy additional recipients on the email.
      # * <tt>:reply_to</tt> - Preset the +Reply-To+ field of the email.
      #
      # ==== Obfuscation
      # Prior to \Rails 4.0, +mail_to+ provided options for encoding the address
      # in order to hinder email harvesters.  To take advantage of these options,
      # install the +actionview-encoded_mail_to+ gem.
      #
      # ==== Examples
      #   mail_to "me@domain.com"
      #   # => <a href="mailto:me@domain.com">me@domain.com</a>
      #
      #   mail_to "me@domain.com", "My email"
      #   # => <a href="mailto:me@domain.com">My email</a>
      #
      #   mail_to "me@domain.com", cc: "ccaddress@domain.com",
      #            subject: "This is an example email"
      #   # => <a href="mailto:me@domain.com?cc=ccaddress@domain.com&subject=This%20is%20an%20example%20email">me@domain.com</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. ERB example:
      #
      #   <%= mail_to "me@domain.com" do %>
      #     <strong>Email me:</strong> <span>me@domain.com</span>
      #   <% end %>
      #   # => <a href="mailto:me@domain.com">
      #          <strong>Email me:</strong> <span>me@domain.com</span>
      #        </a>
      def mail_to(email_address, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        extras = %w{ cc bcc body subject reply_to }.map! { |item|
          option = html_options.delete(item).presence || next
          "#{item.dasherize}=#{ERB::Util.url_encode(option)}"
        }.compact
        extras = extras.empty? ? "" : "?" + extras.join("&")

        encoded_email_address = ERB::Util.url_encode(email_address).gsub("%40", "@")
        html_options["href"] = "mailto:#{encoded_email_address}#{extras}"

        content_tag("a", name || email_address, html_options, &block)
      end

      # Creates an SMS anchor link tag to the specified +phone_number+. When the
      # link is clicked, the default SMS messaging app is opened ready to send a
      # message to the linked phone number. If the +body+ option is specified,
      # the contents of the message will be preset to +body+.
      #
      # If +name+ is not specified, +phone_number+ will be used as the name of
      # the link.
      #
      # A +country_code+ option is supported, which prepends a plus sign and the
      # given country code to the linked phone number. For example,
      # <tt>country_code: "01"</tt> will prepend <tt>+01</tt> to the linked
      # phone number.
      #
      # Additional HTML attributes for the link can be passed via +html_options+.
      #
      # ==== Options
      # * <tt>:country_code</tt> - Prepend the country code to the phone number.
      # * <tt>:body</tt> - Preset the body of the message.
      #
      # ==== Examples
      #   sms_to "5155555785"
      #   # => <a href="sms:5155555785;">5155555785</a>
      #
      #   sms_to "5155555785", country_code: "01"
      #   # => <a href="sms:+015155555785;">5155555785</a>
      #
      #   sms_to "5155555785", "Text me"
      #   # => <a href="sms:5155555785;">Text me</a>
      #
      #   sms_to "5155555785", body: "I have a question about your product."
      #   # => <a href="sms:5155555785;?body=I%20have%20a%20question%20about%20your%20product">5155555785</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. \ERB example:
      #
      #   <%= sms_to "5155555785" do %>
      #     <strong>Text me:</strong>
      #   <% end %>
      #   # => <a href="sms:5155555785;">
      #          <strong>Text me:</strong>
      #        </a>
      def sms_to(phone_number, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        country_code = html_options.delete("country_code").presence
        country_code = country_code ? "+#{ERB::Util.url_encode(country_code)}" : ""

        body = html_options.delete("body").presence
        body = body ? "?&body=#{ERB::Util.url_encode(body)}" : ""

        encoded_phone_number = ERB::Util.url_encode(phone_number)
        html_options["href"] = "sms:#{country_code}#{encoded_phone_number};#{body}"

        content_tag("a", name || phone_number, html_options, &block)
      end

      # Creates a TEL anchor link tag to the specified +phone_number+. When the
      # link is clicked, the default app to make phone calls is opened and
      # prepopulated with the phone number.
      #
      # If +name+ is not specified, +phone_number+ will be used as the name of
      # the link.
      #
      # A +country_code+ option is supported, which prepends a plus sign and the
      # given country code to the linked phone number. For example,
      # <tt>country_code: "01"</tt> will prepend <tt>+01</tt> to the linked
      # phone number.
      #
      # Additional HTML attributes for the link can be passed via +html_options+.
      #
      # ==== Options
      # * <tt>:country_code</tt> - Prepends the country code to the phone number
      #
      # ==== Examples
      #   phone_to "1234567890"
      #   # => <a href="tel:1234567890">1234567890</a>
      #
      #   phone_to "1234567890", "Phone me"
      #   # => <a href="tel:1234567890">Phone me</a>
      #
      #   phone_to "1234567890", country_code: "01"
      #   # => <a href="tel:+011234567890">1234567890</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. \ERB example:
      #
      #   <%= phone_to "1234567890" do %>
      #     <strong>Phone me:</strong>
      #   <% end %>
      #   # => <a href="tel:1234567890">
      #          <strong>Phone me:</strong>
      #        </a>
      def phone_to(phone_number, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        country_code = html_options.delete("country_code").presence
        country_code = country_code.nil? ? "" : "+#{ERB::Util.url_encode(country_code)}"

        encoded_phone_number = ERB::Util.url_encode(phone_number)
        html_options["href"] = "tel:#{country_code}#{encoded_phone_number}"

        content_tag("a", name || phone_number, html_options, &block)
      end
    end
  end
end

require 'cgi'
require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides a number of methods for creating form tags that doesn't rely on conventions with an object assigned to the template like
    # FormHelper does. With the FormTagHelper, you provide the names and values yourself.
    #
    # NOTE: The html options disabled, readonly, and multiple can all be treated as booleans. So specifying <tt>disabled => :true</tt>
    # will give <tt>disabled="disabled"</tt>.
    module FormTagHelper
      # Starts a form tag that points the action to an url configured with <tt>url_for_options</tt> just like
      # ActionController::Base#url_for. The method for the form defaults to POST.
      #
      # Options:
      # * <tt>:multipart</tt> - If set to true, the enctype is set to "multipart/form-data".
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url)
        html_options = { "method" => "post" }.merge(options.stringify_keys)

        if html_options["multipart"]
          html_options["enctype"] = "multipart/form-data"
          html_options.delete("multipart")
        end

        html_options["action"] = url_for(url_for_options, *parameters_for_url)
        tag("form", html_options, true)
      end

      alias_method :start_form_tag, :form_tag

      # Outputs "</form>"
      def end_form_tag
        "</form>"
      end

      def select_tag(name, option_tags = nil, options = {})
        content_tag("select", option_tags, { "name" => name, "id" => name }.update(convert_options(options)))
      end

      def text_field_tag(name, value = nil, options = {})
        tag("input", { "type" => "text", "name" => name, "id" => name, "value" => value }.update(convert_options(options)))
      end

      def hidden_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.stringify_keys.update("type" => "hidden"))
      end

      def file_field_tag(name, options = {})
        text_field_tag(name, nil, convert_options(options).update("type" => "file"))
      end

      def password_field_tag(name = "password", value = nil, options = {})
        text_field_tag(name, value, convert_options(options).update("type" => "password"))
      end

      def text_area_tag(name, content = nil, options = {})
        options = options.stringify_keys
        if options["size"]
          options["cols"], options["rows"] = options["size"].split("x")
          options.delete("size")
        end

        content_tag("textarea", content, { "name" => name, "id" => name }.update(convert_options(options)))
      end

      def check_box_tag(name, value = "1", checked = false, options = {})
        html_options = { "type" => "checkbox", "name" => name, "id" => name, "value" => value }.update(convert_options(options))
        html_options["checked"] = "checked" if checked
        tag("input", html_options)
      end

      def radio_button_tag(name, value, checked = false, options = {})
        html_options = { "type" => "radio", "name" => name, "id" => name, "value" => value }.update(convert_options(options))
        html_options["checked"] = "checked" if checked
        tag("input", html_options)
      end

      def submit_tag(value = "Save changes", options = {})
        tag("input", { "type" => "submit", "name" => "commit", "value" => value }.update(convert_options(options)))
      end
      
      def image_submit_tag(source, options = {})
        tag("input", { "type" => "image", "src" => image_path(source) }.update(convert_options(options)))
      end
      
      private
        def convert_options(options)
          options = options.stringify_keys
          %w( disabled readonly multiple ).each { |a| boolean_attribute(options, a) }
          options
        end
        
        def boolean_attribute(options, attribute)
          if options[attribute]
            options[attribute] = attribute
          else
            options.delete attribute
          end
        end
    end
  end
end

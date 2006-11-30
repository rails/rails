require 'cgi'
require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides a number of methods for creating form tags that doesn't rely on conventions with an object assigned to the template like
    # FormHelper does. With the FormTagHelper, you provide the names and values yourself.
    #
    # NOTE: The html options disabled, readonly, and multiple can all be treated as booleans. So specifying <tt>:disabled => true</tt>
    # will give <tt>disabled="disabled"</tt>.
    module FormTagHelper
      # Starts a form tag that points the action to an url configured with <tt>url_for_options</tt> just like
      # ActionController::Base#url_for. The method for the form defaults to POST.
      #
      # Examples:
      # * <tt>form_tag('/posts') => <form action="/posts" method="post"></tt>
      # * <tt>form_tag('/posts/1', :method => :put) => <form action="/posts/1" method="put"></tt>
      # * <tt>form_tag('/upload', :multipart => true) => <form action="/upload" method="post" enctype="multipart/form-data"></tt>
      # 
      # ERb example:
      #   <% form_tag '/posts' do -%>
      #     <div><%= submit_tag 'Save' %></div>
      #   <% end -%>
      #
      # Will output:
      #   <form action="/posts" method="post"><div><input type="submit" name="submit" value="Save" /></div></form>
      #
      # Options:
      # * <tt>:multipart</tt> - If set to true, the enctype is set to "multipart/form-data".
      # * <tt>:method</tt>    - The method to use when submitting the form, usually either "get" or "post".
      #                         If "put", "delete", or another verb is used, a hidden input with name _method 
      #                         is added to simulate the verb over post.
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
        html_options = options.stringify_keys
        html_options["enctype"] = "multipart/form-data" if html_options.delete("multipart")
        html_options["action"]  = url_for(url_for_options, *parameters_for_url)

        method_tag = ""
        
        case method = html_options.delete("method").to_s
          when /^get$/i # must be case-insentive, but can't use downcase as might be nil
            html_options["method"] = "get"
          when /^post$/i, "", nil
            html_options["method"] = "post"
          else
            html_options["method"] = "post"
            method_tag = content_tag(:div, tag(:input, :type => "hidden", :name => "_method", :value => method), :style => 'margin:0;padding:0')
        end
        
        if block_given?
          content = capture(&block)
          concat(tag(:form, html_options, true) + method_tag, block.binding)
          concat(content, block.binding)
          concat("</form>", block.binding)
        else
          tag(:form, html_options, true) + method_tag
        end
      end

      alias_method :start_form_tag, :form_tag

      # Outputs "</form>"
      def end_form_tag
        "</form>"
      end
      
      deprecate :end_form_tag, :start_form_tag => :form_tag

      # Creates a dropdown selection box, or if the <tt>:multiple</tt> option is set to true, a multiple
      # choice selection box.
      #
      # Helpers::FormOptions can be used to create common select boxes such as countries, time zones, or
      # associated records.
      #
      # <tt>option_tags</tt> is a string containing the option tags for the select box:
      #   # Outputs <select id="people" name="people"><option>David</option></select>
      #   select_tag "people", "<option>David</option>"
      #
      # Options:
      # * <tt>:multiple</tt> - If set to true the selection will allow multiple choices.
      def select_tag(name, option_tags = nil, options = {})
        content_tag :select, option_tags, { "name" => name, "id" => name }.update(options.stringify_keys)
      end

      # Creates a standard text field.
      #
      # Options:
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:size</tt> - The number of visible characters that will fit in the input.
      # * <tt>:maxlength</tt> - The maximum number of characters that the browser will allow the user to enter.
      # 
      # A hash of standard HTML options for the tag.
      def text_field_tag(name, value = nil, options = {})
        tag :input, { "type" => "text", "name" => name, "id" => name, "value" => value }.update(options.stringify_keys)
      end

      # Creates a hidden field.
      #
      # Takes the same options as text_field_tag
      def hidden_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.stringify_keys.update("type" => "hidden"))
      end

      # Creates a file upload field.
      #
      # If you are using file uploads then you will also need to set the multipart option for the form:
      #   <%= form_tag { :action => "post" }, { :multipart => true } %>
      #     <label for="file">File to Upload</label> <%= file_field_tag "file" %>
      #     <%= submit_tag %>
      #   <%= end_form_tag %>
      #
      # The specified URL will then be passed a File object containing the selected file, or if the field 
      # was left blank, a StringIO object.
      def file_field_tag(name, options = {})
        text_field_tag(name, nil, options.update("type" => "file"))
      end

      # Creates a password field.
      #
      # Takes the same options as text_field_tag
      def password_field_tag(name = "password", value = nil, options = {})
        text_field_tag(name, value, options.update("type" => "password"))
      end

      # Creates a text input area.
      #
      # Options:
      # * <tt>:size</tt> - A string specifying the dimensions of the textarea.
      #     # Outputs <textarea name="body" id="body" cols="25" rows="10"></textarea>
      #     <%= text_area_tag "body", nil, :size => "25x10" %>
      def text_area_tag(name, content = nil, options = {})
        options.stringify_keys!

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x")
        end

        content_tag :textarea, content, { "name" => name, "id" => name }.update(options.stringify_keys)
      end

      # Creates a check box.
      def check_box_tag(name, value = "1", checked = false, options = {})
        html_options = { "type" => "checkbox", "name" => name, "id" => name, "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a radio button.
      def radio_button_tag(name, value, checked = false, options = {})
        pretty_tag_value = value.to_s.gsub(/\s/, "_").gsub(/(?!-)\W/, "").downcase
        html_options = { "type" => "radio", "name" => name, "id" => "#{name}_#{pretty_tag_value}", "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a submit button with the text <tt>value</tt> as the caption. If options contains a pair with the key of "disable_with",
      # then the value will be used to rename a disabled version of the submit button.
      def submit_tag(value = "Save changes", options = {})
        options.stringify_keys!
        
        if disable_with = options.delete("disable_with")
          options["onclick"] = "this.disabled=true;this.value='#{disable_with}';this.form.submit();#{options["onclick"]}"
        end
          
        tag :input, { "type" => "submit", "name" => "commit", "value" => value }.update(options.stringify_keys)
      end
      
      # Displays an image which when clicked will submit the form.
      #
      # <tt>source</tt> is passed to AssetTagHelper#image_path
      def image_submit_tag(source, options = {})
        tag :input, { "type" => "image", "src" => image_path(source) }.update(options.stringify_keys)
      end
    end
  end
end

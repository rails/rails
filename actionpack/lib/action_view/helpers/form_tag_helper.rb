require 'cgi'
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    # Provides a number of methods for creating form tags that doesn't rely on an Active Record object assigned to the template like
    # FormHelper does. Instead, you provide the names and values manually.
    #
    # NOTE: The HTML options <tt>disabled</tt>, <tt>readonly</tt>, and <tt>multiple</tt> can all be treated as booleans. So specifying
    # <tt>:disabled => true</tt> will give <tt>disabled="disabled"</tt>.
    module FormTagHelper
      # Starts a form tag that points the action to an url configured with <tt>url_for_options</tt> just like
      # ActionController::Base#url_for. The method for the form defaults to POST.
      #
      # ==== Options
      # * <tt>:multipart</tt> - If set to true, the enctype is set to "multipart/form-data".
      # * <tt>:method</tt> - The method to use when submitting the form, usually either "get" or "post".
      #   If "put", "delete", or another verb is used, a hidden input with name <tt>_method</tt>
      #   is added to simulate the verb over post.
      # * A list of parameters to feed to the URL the form will be posted to.
      #
      # ==== Examples
      #   form_tag('/posts')
      #   # => <form action="/posts" method="post">
      #
      #   form_tag('/posts/1', :method => :put)
      #   # => <form action="/posts/1" method="put">
      #
      #   form_tag('/upload', :multipart => true)
      #   # => <form action="/upload" method="post" enctype="multipart/form-data">
      #
      #   <% form_tag '/posts' do -%>
      #     <div><%= submit_tag 'Save' %></div>
      #   <% end -%>
      #   # => <form action="/posts" method="post"><div><input type="submit" name="submit" value="Save" /></div></form>
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
        html_options = html_options_for_form(url_for_options, options, *parameters_for_url)
        if block_given?
          form_tag_in_block(html_options, &block)
        else
          form_tag_html(html_options)
        end
      end

      # Creates a dropdown selection box, or if the <tt>:multiple</tt> option is set to true, a multiple
      # choice selection box.
      #
      # Helpers::FormOptions can be used to create common select boxes such as countries, time zones, or
      # associated records. <tt>option_tags</tt> is a string containing the option tags for the select box.
      #
      # ==== Options
      # * <tt>:multiple</tt> - If set to true the selection will allow multiple choices.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   select_tag "people", "<option>David</option>"
      #   # => <select id="people" name="people"><option>David</option></select>
      #
      #   select_tag "count", "<option>1</option><option>2</option><option>3</option><option>4</option>"
      #   # => <select id="count" name="count"><option>1</option><option>2</option>
      #   #    <option>3</option><option>4</option></select>
      #
      #   select_tag "colors", "<option>Red</option><option>Green</option><option>Blue</option>", :multiple => true
      #   # => <select id="colors" multiple="multiple" name="colors[]"><option>Red</option>
      #   #    <option>Green</option><option>Blue</option></select>
      #
      #   select_tag "locations", "<option>Home</option><option selected="selected">Work</option><option>Out</option>"
      #   # => <select id="locations" name="locations"><option>Home</option><option selected='selected'>Work</option>
      #   #    <option>Out</option></select>
      #
      #   select_tag "access", "<option>Read</option><option>Write</option>", :multiple => true, :class => 'form_input'
      #   # => <select class="form_input" id="access" multiple="multiple" name="access[]"><option>Read</option>
      #   #    <option>Write</option></select>
      #
      #   select_tag "destination", "<option>NYC</option><option>Paris</option><option>Rome</option>", :disabled => true
      #   # => <select disabled="disabled" id="destination" name="destination"><option>NYC</option>
      #   #    <option>Paris</option><option>Rome</option></select>
      def select_tag(name, option_tags = nil, options = {})
        html_name = (options[:multiple] == true && !name.to_s.ends_with?("[]")) ? "#{name}[]" : name
        content_tag :select, option_tags, { "name" => html_name, "id" => sanitize_to_id(name) }.update(options.stringify_keys)
      end

      # Creates a standard text field; use these text fields to input smaller chunks of text like a username
      # or a search query.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:size</tt> - The number of visible characters that will fit in the input.
      # * <tt>:maxlength</tt> - The maximum number of characters that the browser will allow the user to enter.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   text_field_tag 'name'
      #   # => <input id="name" name="name" type="text" />
      #
      #   text_field_tag 'query', 'Enter your search query here'
      #   # => <input id="query" name="query" type="text" value="Enter your search query here" />
      #
      #   text_field_tag 'request', nil, :class => 'special_input'
      #   # => <input class="special_input" id="request" name="request" type="text" />
      #
      #   text_field_tag 'address', '', :size => 75
      #   # => <input id="address" name="address" size="75" type="text" value="" />
      #
      #   text_field_tag 'zip', nil, :maxlength => 5
      #   # => <input id="zip" maxlength="5" name="zip" type="text" />
      #
      #   text_field_tag 'payment_amount', '$0.00', :disabled => true
      #   # => <input disabled="disabled" id="payment_amount" name="payment_amount" type="text" value="$0.00" />
      #
      #   text_field_tag 'ip', '0.0.0.0', :maxlength => 15, :size => 20, :class => "ip-input"
      #   # => <input class="ip-input" id="ip" maxlength="15" name="ip" size="20" type="text" value="0.0.0.0" />
      def text_field_tag(name, value = nil, options = {})
        tag :input, { "type" => "text", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
      end

      # Creates a label field
      #
      # ==== Options  
      # * Creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   label_tag 'name'
      #   # => <label for="name">Name</label>
      #
      #   label_tag 'name', 'Your name'
      #   # => <label for="name">Your Name</label>
      #
      #   label_tag 'name', nil, :class => 'small_label'
      #   # => <label for="name" class="small_label">Name</label>
      def label_tag(name, text = nil, options = {})
        content_tag :label, text || name.to_s.humanize, { "for" => sanitize_to_id(name) }.update(options.stringify_keys)
      end

      # Creates a hidden form input field used to transmit data that would be lost due to HTTP's statelessness or
      # data that should be hidden from the user.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   hidden_field_tag 'tags_list'
      #   # => <input id="tags_list" name="tags_list" type="hidden" />
      #
      #   hidden_field_tag 'token', 'VUBJKB23UIVI1UU1VOBVI@'
      #   # => <input id="token" name="token" type="hidden" value="VUBJKB23UIVI1UU1VOBVI@" />
      #
      #   hidden_field_tag 'collected_input', '', :onchange => "alert('Input collected!')"
      #   # => <input id="collected_input" name="collected_input" onchange="alert('Input collected!')"
      #   #    type="hidden" value="" />
      def hidden_field_tag(name, value = nil, options = {})
        text_field_tag(name, value, options.stringify_keys.update("type" => "hidden"))
      end

      # Creates a file upload field.  If you are using file uploads then you will also need
      # to set the multipart option for the form tag:
      #
      #   <% form_tag '/upload', :multipart => true do %>
      #     <label for="file">File to Upload</label> <%= file_field_tag "file" %>
      #     <%= submit_tag %>
      #   <% end %>
      #
      # The specified URL will then be passed a File object containing the selected file, or if the field
      # was left blank, a StringIO object.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      #
      # ==== Examples
      #   file_field_tag 'attachment'
      #   # => <input id="attachment" name="attachment" type="file" />
      #
      #   file_field_tag 'avatar', :class => 'profile-input'
      #   # => <input class="profile-input" id="avatar" name="avatar" type="file" />
      #
      #   file_field_tag 'picture', :disabled => true
      #   # => <input disabled="disabled" id="picture" name="picture" type="file" />
      #
      #   file_field_tag 'resume', :value => '~/resume.doc'
      #   # => <input id="resume" name="resume" type="file" value="~/resume.doc" />
      #
      #   file_field_tag 'user_pic', :accept => 'image/png,image/gif,image/jpeg'
      #   # => <input accept="image/png,image/gif,image/jpeg" id="user_pic" name="user_pic" type="file" />
      #
      #   file_field_tag 'file', :accept => 'text/html', :class => 'upload', :value => 'index.html'
      #   # => <input accept="text/html" class="upload" id="file" name="file" type="file" value="index.html" />
      def file_field_tag(name, options = {})
        text_field_tag(name, nil, options.update("type" => "file"))
      end

      # Creates a password field, a masked text field that will hide the users input behind a mask character.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:size</tt> - The number of visible characters that will fit in the input.
      # * <tt>:maxlength</tt> - The maximum number of characters that the browser will allow the user to enter.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   password_field_tag 'pass'
      #   # => <input id="pass" name="pass" type="password" />
      #
      #   password_field_tag 'secret', 'Your secret here'
      #   # => <input id="secret" name="secret" type="password" value="Your secret here" />
      #
      #   password_field_tag 'masked', nil, :class => 'masked_input_field'
      #   # => <input class="masked_input_field" id="masked" name="masked" type="password" />
      #
      #   password_field_tag 'token', '', :size => 15
      #   # => <input id="token" name="token" size="15" type="password" value="" />
      #
      #   password_field_tag 'key', nil, :maxlength => 16
      #   # => <input id="key" maxlength="16" name="key" type="password" />
      #
      #   password_field_tag 'confirm_pass', nil, :disabled => true
      #   # => <input disabled="disabled" id="confirm_pass" name="confirm_pass" type="password" />
      #
      #   password_field_tag 'pin', '1234', :maxlength => 4, :size => 6, :class => "pin-input"
      #   # => <input class="pin-input" id="pin" maxlength="4" name="pin" size="6" type="password" value="1234" />
      def password_field_tag(name = "password", value = nil, options = {})
        text_field_tag(name, value, options.update("type" => "password"))
      end

      # Creates a text input area; use a textarea for longer text inputs such as blog posts or descriptions.
      #
      # ==== Options
      # * <tt>:size</tt> - A string specifying the dimensions (columns by rows) of the textarea (e.g., "25x10").
      # * <tt>:rows</tt> - Specify the number of rows in the textarea
      # * <tt>:cols</tt> - Specify the number of columns in the textarea
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:escape</tt> - By default, the contents of the text input are HTML escaped.
      #   If you need unescaped contents, set this to false.
      # * Any other key creates standard HTML attributes for the tag.
      #
      # ==== Examples
      #   text_area_tag 'post'
      #   # => <textarea id="post" name="post"></textarea>
      #
      #   text_area_tag 'bio', @user.bio
      #   # => <textarea id="bio" name="bio">This is my biography.</textarea>
      #
      #   text_area_tag 'body', nil, :rows => 10, :cols => 25
      #   # => <textarea cols="25" id="body" name="body" rows="10"></textarea>
      #
      #   text_area_tag 'body', nil, :size => "25x10"
      #   # => <textarea name="body" id="body" cols="25" rows="10"></textarea>
      #
      #   text_area_tag 'description', "Description goes here.", :disabled => true
      #   # => <textarea disabled="disabled" id="description" name="description">Description goes here.</textarea>
      #
      #   text_area_tag 'comment', nil, :class => 'comment_input'
      #   # => <textarea class="comment_input" id="comment" name="comment"></textarea>
      def text_area_tag(name, content = nil, options = {})
        options.stringify_keys!

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
        end

        escape = options.key?("escape") ? options.delete("escape") : true
        content = html_escape(content) if escape

        content_tag :textarea, content, { "name" => name, "id" => sanitize_to_id(name) }.update(options.stringify_keys)
      end

      # Creates a check box form input tag.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   check_box_tag 'accept'
      #   # => <input id="accept" name="accept" type="checkbox" value="1" />
      #
      #   check_box_tag 'rock', 'rock music'
      #   # => <input id="rock" name="rock" type="checkbox" value="rock music" />
      #
      #   check_box_tag 'receive_email', 'yes', true
      #   # => <input checked="checked" id="receive_email" name="receive_email" type="checkbox" value="yes" />
      #
      #   check_box_tag 'tos', 'yes', false, :class => 'accept_tos'
      #   # => <input class="accept_tos" id="tos" name="tos" type="checkbox" value="yes" />
      #
      #   check_box_tag 'eula', 'accepted', false, :disabled => true
      #   # => <input disabled="disabled" id="eula" name="eula" type="checkbox" value="accepted" />
      def check_box_tag(name, value = "1", checked = false, options = {})
        html_options = { "type" => "checkbox", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a radio button; use groups of radio buttons named the same to allow users to
      # select from a group of options.
      #
      # ==== Options
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   radio_button_tag 'gender', 'male'
      #   # => <input id="gender_male" name="gender" type="radio" value="male" />
      #
      #   radio_button_tag 'receive_updates', 'no', true
      #   # => <input checked="checked" id="receive_updates_no" name="receive_updates" type="radio" value="no" />
      #
      #   radio_button_tag 'time_slot', "3:00 p.m.", false, :disabled => true
      #   # => <input disabled="disabled" id="time_slot_300_pm" name="time_slot" type="radio" value="3:00 p.m." />
      #
      #   radio_button_tag 'color', "green", true, :class => "color_input"
      #   # => <input checked="checked" class="color_input" id="color_green" name="color" type="radio" value="green" />
      def radio_button_tag(name, value, checked = false, options = {})
        pretty_tag_value = value.to_s.gsub(/\s/, "_").gsub(/(?!-)\W/, "").downcase
        pretty_name = name.to_s.gsub(/\[/, "_").gsub(/\]/, "")
        html_options = { "type" => "radio", "name" => name, "id" => "#{pretty_name}_#{pretty_tag_value}", "value" => value }.update(options.stringify_keys)
        html_options["checked"] = "checked" if checked
        tag :input, html_options
      end

      # Creates a submit button with the text <tt>value</tt> as the caption.
      #
      # ==== Options
      # * <tt>:confirm => 'question?'</tt> - This will add a JavaScript confirm
      #   prompt with the question specified. If the user accepts, the form is
      #   processed normally, otherwise no action is taken.
      # * <tt>:disabled</tt> - If true, the user will not be able to use this input.
      # * <tt>:disable_with</tt> - Value of this parameter will be used as the value for a disabled version
      #   of the submit button when the form is submitted.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   submit_tag
      #   # => <input name="commit" type="submit" value="Save changes" />
      #
      #   submit_tag "Edit this article"
      #   # => <input name="commit" type="submit" value="Edit this article" />
      #
      #   submit_tag "Save edits", :disabled => true
      #   # => <input disabled="disabled" name="commit" type="submit" value="Save edits" />
      #
      #   submit_tag "Complete sale", :disable_with => "Please wait..."
      #   # => <input name="commit" onclick="this.disabled=true;this.value='Please wait...';this.form.submit();"
      #   #    type="submit" value="Complete sale" />
      #
      #   submit_tag nil, :class => "form_submit"
      #   # => <input class="form_submit" name="commit" type="submit" />
      #
      #   submit_tag "Edit", :disable_with => "Editing...", :class => "edit-button"
      #   # => <input class="edit-button" onclick="this.disabled=true;this.value='Editing...';this.form.submit();"
      #   #    name="commit" type="submit" value="Edit" />
      def submit_tag(value = "Save changes", options = {})
        options.stringify_keys!

        if disable_with = options.delete("disable_with")
          disable_with = "this.value='#{disable_with}'"
          disable_with << ";#{options.delete('onclick')}" if options['onclick']
          
          options["onclick"]  = "if (window.hiddenCommit) { window.hiddenCommit.setAttribute('value', this.value); }"
          options["onclick"] << "else { hiddenCommit = document.createElement('input');hiddenCommit.type = 'hidden';"
          options["onclick"] << "hiddenCommit.value = this.value;hiddenCommit.name = this.name;this.form.appendChild(hiddenCommit); }"
          options["onclick"] << "this.setAttribute('originalValue', this.value);this.disabled = true;#{disable_with};"
          options["onclick"] << "result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());"
          options["onclick"] << "if (result == false) { this.value = this.getAttribute('originalValue');this.disabled = false; }return result;"
        end

        if confirm = options.delete("confirm")
          options["onclick"] ||= 'return true;'
          options["onclick"] = "if (!#{confirm_javascript_function(confirm)}) return false; #{options['onclick']}"
        end

        tag :input, { "type" => "submit", "name" => "commit", "value" => value }.update(options.stringify_keys)
      end

      # Displays an image which when clicked will submit the form.
      #
      # <tt>source</tt> is passed to AssetTagHelper#image_path
      #
      # ==== Options
      # * <tt>:confirm => 'question?'</tt> - This will add a JavaScript confirm
      #   prompt with the question specified. If the user accepts, the form is
      #   processed normally, otherwise no action is taken.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * Any other key creates standard HTML options for the tag.
      #
      # ==== Examples
      #   image_submit_tag("login.png")
      #   # => <input src="/images/login.png" type="image" />
      #
      #   image_submit_tag("purchase.png", :disabled => true)
      #   # => <input disabled="disabled" src="/images/purchase.png" type="image" />
      #
      #   image_submit_tag("search.png", :class => 'search-button')
      #   # => <input class="search-button" src="/images/search.png" type="image" />
      #
      #   image_submit_tag("agree.png", :disabled => true, :class => "agree-disagree-button")
      #   # => <input class="agree-disagree-button" disabled="disabled" src="/images/agree.png" type="image" />
      def image_submit_tag(source, options = {})
        options.stringify_keys!

        if confirm = options.delete("confirm")
          options["onclick"] ||= ''
          options["onclick"] += "return #{confirm_javascript_function(confirm)};"
        end

        tag :input, { "type" => "image", "src" => path_to_image(source) }.update(options.stringify_keys)
      end

      # Creates a field set for grouping HTML form elements.
      #
      # <tt>legend</tt> will become the fieldset's title (optional as per W3C).
      # <tt>options</tt> accept the same values as tag.
      #
      # === Examples
      #   <% field_set_tag do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset><p><input id="name" name="name" type="text" /></p></fieldset>
      #
      #   <% field_set_tag 'Your details' do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset><legend>Your details</legend><p><input id="name" name="name" type="text" /></p></fieldset>
      #
      #   <% field_set_tag nil, :class => 'format' do %>
      #     <p><%= text_field_tag 'name' %></p>
      #   <% end %>
      #   # => <fieldset class="format"><p><input id="name" name="name" type="text" /></p></fieldset>
      def field_set_tag(legend = nil, options = nil, &block)
        content = capture(&block)
        concat(tag(:fieldset, options, true))
        concat(content_tag(:legend, legend)) unless legend.blank?
        concat(content)
        concat("</fieldset>")
      end

      private
        def html_options_for_form(url_for_options, options, *parameters_for_url)
          returning options.stringify_keys do |html_options|
            html_options["enctype"] = "multipart/form-data" if html_options.delete("multipart")
            html_options["action"]  = url_for(url_for_options, *parameters_for_url)
          end
        end

        def extra_tags_for_form(html_options)
          case method = html_options.delete("method").to_s
            when /^get$/i # must be case-insentive, but can't use downcase as might be nil
              html_options["method"] = "get"
              ''
            when /^post$/i, "", nil
              html_options["method"] = "post"
              protect_against_forgery? ? content_tag(:div, token_tag, :style => 'margin:0;padding:0;display:inline') : ''
            else
              html_options["method"] = "post"
              content_tag(:div, tag(:input, :type => "hidden", :name => "_method", :value => method) + token_tag, :style => 'margin:0;padding:0;display:inline')
          end
        end

        def form_tag_html(html_options)
          extra_tags = extra_tags_for_form(html_options)
          (tag(:form, html_options, true) + extra_tags).html_safe
        end

        def form_tag_in_block(html_options, &block)
          content = capture(&block)
          concat(form_tag_html(html_options))
          concat(content)
          concat("</form>")
        end

        def token_tag
          unless protect_against_forgery?
            ''
          else
            tag(:input, :type => "hidden", :name => request_forgery_protection_token.to_s, :value => form_authenticity_token)
          end
        end

        # see http://www.w3.org/TR/html4/types.html#type-name
        def sanitize_to_id(name)
          name.to_s.gsub(']','').gsub(/[^-a-zA-Z0-9:.]/, "_")
        end

    end
  end
end

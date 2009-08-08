require 'cgi'
require 'action_view/helpers/form_helper'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/kernel/reporting'

module ActionView
  class Base
    @@field_error_proc = Proc.new{ |html_tag, instance| "<div class=\"fieldWithErrors\">#{html_tag}</div>" }
    cattr_accessor :field_error_proc
  end

  module Helpers
    # The Active Record Helper makes it easier to create forms for records kept in instance variables. The most far-reaching is the +form+
    # method that creates a complete form for all the basic content types of the record (not associations or aggregations, though). This
    # is a great way of making the record quickly available for editing, but likely to prove lackluster for a complicated real-world form.
    # In that case, it's better to use the +input+ method and the specialized +form+ methods in link:classes/ActionView/Helpers/FormHelper.html
    module ActiveModelHelper
      # Returns a default input tag for the type of object returned by the method. For example, if <tt>@post</tt>
      # has an attribute +title+ mapped to a +VARCHAR+ column that holds "Hello World":
      #
      #   input("post", "title")
      #   # => <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      def input(record_name, method, options = {})
        InstanceTag.new(record_name, method, self).to_tag(options)
      end

      # Returns an entire form with all needed input tags for a specified Active Record object. For example, if <tt>@post</tt>
      # has attributes named +title+ of type +VARCHAR+ and +body+ of type +TEXT+ then
      #
      #   form("post")
      #
      # would yield a form like the following (modulus formatting):
      #
      #   <form action='/posts/create' method='post'>
      #     <p>
      #       <label for="post_title">Title</label><br />
      #       <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      #     </p>
      #     <p>
      #       <label for="post_body">Body</label><br />
      #       <textarea cols="40" id="post_body" name="post[body]" rows="20"></textarea>
      #     </p>
      #     <input name="commit" type="submit" value="Create" />
      #   </form>
      #
      # It's possible to specialize the form builder by using a different action name and by supplying another
      # block renderer. For example, if <tt>@entry</tt> has an attribute +message+ of type +VARCHAR+ then
      #
      #   form("entry",
      #     :action => "sign",
      #     :input_block => Proc.new { |record, column|
      #       "#{column.human_name}: #{input(record, column.name)}<br />"
      #   })
      #
      # would yield a form like the following (modulus formatting):
      #
      #   <form action="/entries/sign" method="post">
      #     Message:
      #     <input id="entry_message" name="entry[message]" size="30" type="text" /><br />
      #     <input name="commit" type="submit" value="Sign" />
      #   </form>
      #
      # It's also possible to add additional content to the form by giving it a block, such as:
      #
      #   form("entry", :action => "sign") do |form|
      #     form << content_tag("b", "Department")
      #     form << collection_select("department", "id", @departments, "id", "name")
      #   end
      #
      # The following options are available:
      #
      # * <tt>:action</tt> - The action used when submitting the form (default: +create+ if a new record, otherwise +update+).
      # * <tt>:input_block</tt> - Specialize the output using a different block, see above.
      # * <tt>:method</tt> - The method used when submitting the form (default: +post+).
      # * <tt>:multipart</tt> - Whether to change the enctype of the form to "multipart/form-data", used when uploading a file (default: +false+).
      # * <tt>:submit_value</tt> - The text of the submit button (default: "Create" if a new record, otherwise "Update").
      def form(record_name, options = {})
        record = instance_variable_get("@#{record_name}")
        record = convert_to_model(record)

        options = options.symbolize_keys
        options[:action] ||= record.new_record? ? "create" : "update"
        action = url_for(:action => options[:action], :id => record)

        submit_value = options[:submit_value] || options[:action].gsub(/[^\w]/, '').capitalize

        contents = form_tag({:action => action}, :method =>(options[:method] || 'post'), :enctype => options[:multipart] ? 'multipart/form-data': nil)
        contents << hidden_field(record_name, :id) unless record.new_record?
        contents << all_input_tags(record, record_name, options)
        yield contents if block_given?
        contents << submit_tag(submit_value)
        contents << '</form>'
      end

      # Returns a string containing the error message attached to the +method+ on the +object+ if one exists.
      # This error message is wrapped in a <tt>DIV</tt> tag, which can be extended to include a <tt>:prepend_text</tt>
      # and/or <tt>:append_text</tt> (to properly explain the error), and a <tt>:css_class</tt> to style it
      # accordingly. +object+ should either be the name of an instance variable or the actual object. The method can be
      # passed in either as a string or a symbol.
      # As an example, let's say you have a model <tt>@post</tt> that has an error message on the +title+ attribute:
      #
      #   <%= error_message_on "post", "title" %>
      #   # => <div class="formError">can't be empty</div>
      #
      #   <%= error_message_on @post, :title %>
      #   # => <div class="formError">can't be empty</div>
      #
      #   <%= error_message_on "post", "title",
      #       :prepend_text => "Title simply ",
      #       :append_text => " (or it won't work).",
      #       :css_class => "inputError" %>
      def error_message_on(object, method, *args)
        options = args.extract_options!
        unless args.empty?
          ActiveSupport::Deprecation.warn('error_message_on takes an option hash instead of separate ' +
            'prepend_text, append_text, and css_class arguments', caller)

          options[:prepend_text] = args[0] || ''
          options[:append_text] = args[1] || ''
          options[:css_class] = args[2] || 'formError'
        end
        options.reverse_merge!(:prepend_text => '', :append_text => '', :css_class => 'formError')

        object = convert_to_model(object)

        if (obj = (object.respond_to?(:errors) ? object : instance_variable_get("@#{object}"))) &&
          (errors = obj.errors[method])
          content_tag("div",
            "#{options[:prepend_text]}#{ERB::Util.html_escape(errors.first)}#{options[:append_text]}",
            :class => options[:css_class]
          )
        else
          ''
        end
      end

      # Returns a string with a <tt>DIV</tt> containing all of the error messages for the objects located as instance variables by the names
      # given.  If more than one object is specified, the errors for the objects are displayed in the order that the object names are
      # provided.
      #
      # This <tt>DIV</tt> can be tailored by the following options:
      #
      # * <tt>:header_tag</tt> - Used for the header of the error div (default: "h2").
      # * <tt>:id</tt> - The id of the error div (default: "errorExplanation").
      # * <tt>:class</tt> - The class of the error div (default: "errorExplanation").
      # * <tt>:object</tt> - The object (or array of objects) for which to display errors,
      #   if you need to escape the instance variable convention.
      # * <tt>:object_name</tt> - The object name to use in the header, or any text that you prefer.
      #   If <tt>:object_name</tt> is not set, the name of the first object will be used.
      # * <tt>:header_message</tt> - The message in the header of the error div.  Pass +nil+
      #   or an empty string to avoid the header message altogether. (Default: "X errors
      #   prohibited this object from being saved").
      # * <tt>:message</tt> - The explanation message after the header message and before
      #   the error list.  Pass +nil+ or an empty string to avoid the explanation message
      #   altogether. (Default: "There were problems with the following fields:").
      #
      # To specify the display for one object, you simply provide its name as a parameter.
      # For example, for the <tt>@user</tt> model:
      #
      #   error_messages_for 'user'
      #
      # You can also supply an object:
      #
      #   error_messages_for @user
      #
      # This will use the last part of the model name in the presentation. For instance, if
      # this is a MyKlass::User object, this will use "user" as the name in the String. This
      # is taken from MyKlass::User.model_name.human, which can be overridden.
      #
      # To specify more than one object, you simply list them; optionally, you can add an extra <tt>:object_name</tt> parameter, which
      # will be the name used in the header message:
      #
      #   error_messages_for 'user_common', 'user', :object_name => 'user'
      #
      # You can also use a number of objects, which will have the same naming semantics
      # as a single object.
      #
      #   error_messages_for @user, @post
      #
      # If the objects cannot be located as instance variables, you can add an extra <tt>:object</tt> parameter which gives the actual
      # object (or array of objects to use):
      #
      #   error_messages_for 'user', :object => @question.user
      #
      # NOTE: This is a pre-packaged presentation of the errors with embedded strings and a certain HTML structure. If what
      # you need is significantly different from the default presentation, it makes plenty of sense to access the <tt>object.errors</tt>
      # instance yourself and set it up. View the source of this method to see how easy it is.
      def error_messages_for(*params)
        options = params.extract_options!.symbolize_keys

        objects = Array.wrap(options.delete(:object) || params).map do |object|
          unless object.respond_to?(:to_model)
            object = instance_variable_get("@#{object}")
            object = convert_to_model(object)
          else
            object = object.to_model
            options[:object_name] ||= object.class.model_name.human
          end
          object
        end

        objects.compact!

        count = objects.inject(0) {|sum, object| sum + object.errors.count }
        unless count.zero?
          html = {}
          [:id, :class].each do |key|
            if options.include?(key)
              value = options[key]
              html[key] = value unless value.blank?
            else
              html[key] = 'errorExplanation'
            end
          end
          options[:object_name] ||= params.first

          I18n.with_options :locale => options[:locale], :scope => [:activerecord, :errors, :template] do |locale|
            header_message = if options.include?(:header_message)
              options[:header_message]
            else
              object_name = options[:object_name].to_s.gsub('_', ' ')
              object_name = I18n.t(options[:object_name].to_s, :default => object_name, :scope => [:activerecord, :models], :count => 1)
              locale.t :header, :count => count, :model => object_name
            end
            message = options.include?(:message) ? options[:message] : locale.t(:body)
            error_messages = objects.sum {|object| object.errors.full_messages.map {|msg| content_tag(:li, ERB::Util.html_escape(msg)) } }.join

            contents = ''
            contents << content_tag(options[:header_tag] || :h2, header_message) unless header_message.blank?
            contents << content_tag(:p, message) unless message.blank?
            contents << content_tag(:ul, error_messages)

            content_tag(:div, contents, html)
          end
        else
          ''
        end
      end

      private
        def all_input_tags(record, record_name, options)
          input_block = options[:input_block] || default_input_block
          record.class.content_columns.collect{ |column| input_block.call(record_name, column) }.join("\n")
        end

        def default_input_block
          Proc.new { |record, column| %(<p><label for="#{record}_#{column.name}">#{column.human_name}</label><br />#{input(record, column.name)}</p>) }
        end
    end

    module ActiveRecordInstanceTag
      def object
        @active_model_object ||= begin
          object = super
          object.respond_to?(:to_model) ? object.to_model : object
        end
      end

      def to_tag(options = {})
        case column_type
          when :string
            field_type = @method_name.include?("password") ? "password" : "text"
            to_input_field_tag(field_type, options)
          when :text
            to_text_area_tag(options)
          when :integer, :float, :decimal
            to_input_field_tag("text", options)
          when :date
            to_date_select_tag(options)
          when :datetime, :timestamp
            to_datetime_select_tag(options)
          when :time
            to_time_select_tag(options)
          when :boolean
            to_boolean_select_tag(options)
        end
      end

      %w(tag content_tag to_date_select_tag to_datetime_select_tag to_time_select_tag).each do |meth|
        module_eval "def #{meth}(*) error_wrapping(super) end"
      end

      def error_wrapping(html_tag)
        if object.respond_to?(:errors) && object.errors.respond_to?(:full_messages) && object.errors[@method_name].any?
          Base.field_error_proc.call(html_tag, self)
        else
          html_tag
        end
      end

      def column_type
        object.send(:column_for_attribute, @method_name).type
      end
    end

    class InstanceTag
      include ActiveRecordInstanceTag
    end
  end
end

require 'cgi'
require 'action_view/helpers/form_helper'

module ActionView
  class Base
    @@field_error_proc = Proc.new{ |html_tag, instance| "<div class=\"fieldWithErrors\">#{html_tag}</div>" }
    cattr_accessor :field_error_proc
  end

  module Helpers
    # The Active Record Helper makes it easier to create forms for records kept in instance variables. The most far-reaching is the form
    # method that creates a complete form for all the basic content types of the record (not associations or aggregations, though). This
    # is a great way of making the record quickly available for editing, but likely to prove lackluster for a complicated real-world form.
    # In that case, it's better to use the input method and the specialized form methods in link:classes/ActionView/Helpers/FormHelper.html
    module ActiveRecordHelper
      # Returns a default input tag for the type of object returned by the method. For example, let's say you have a model
      # that has an attribute +title+ of type VARCHAR column, and this instance holds "Hello World":
      #   input("post", "title") =>
      #     <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      def input(record_name, method, options = {})
        InstanceTag.new(record_name, method, self).to_tag(options)
      end

      # Returns an entire form with all needed input tags for a specified Active Record object. For example, let's say you 
      # have a table model <tt>Post</tt> with attributes named <tt>title</tt> of type <tt>VARCHAR</tt> and <tt>body</tt> of type <tt>TEXT</tt>:
      #   form("post") 
      # That line would yield a form like the following:
      #     <form action='/post/create' method='post'>
      #       <p>
      #         <label for="post_title">Title</label><br />
      #         <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      #       </p>
      #       <p>
      #         <label for="post_body">Body</label><br />
      #         <textarea cols="40" id="post_body" name="post[body]" rows="20">
      #         </textarea>
      #       </p>
      #       <input type='submit' value='Create' />
      #     </form>
      #
      # It's possible to specialize the form builder by using a different action name and by supplying another
      # block renderer. For example, let's say you have a model <tt>Entry</tt> with an attribute <tt>message</tt> of type <tt>VARCHAR</tt>:
      #
      #   form("entry", :action => "sign", :input_block =>
      #        Proc.new { |record, column| "#{column.human_name}: #{input(record, column.name)}<br />" }) =>
      #
      #     <form action='/post/sign' method='post'>
      #       Message:
      #       <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" /><br />
      #       <input type='submit' value='Sign' />
      #     </form>
      #
      # It's also possible to add additional content to the form by giving it a block, such as:
      #
      #   form("entry", :action => "sign") do |form|
      #     form << content_tag("b", "Department")
      #     form << collection_select("department", "id", @departments, "id", "name")
      #   end
      def form(record_name, options = {})
        record = instance_variable_get("@#{record_name}")

        options = options.symbolize_keys
        options[:action] ||= record.new_record? ? "create" : "update"
        action = url_for(:action => options[:action], :id => record)

        submit_value = options[:submit_value] || options[:action].gsub(/[^\w]/, '').capitalize

        contents = ''
        contents << hidden_field(record_name, :id) unless record.new_record?
        contents << all_input_tags(record, record_name, options)
        yield contents if block_given?
        contents << submit_tag(submit_value)

        content_tag('form', contents, :action => action, :method => 'post', :enctype => options[:multipart] ? 'multipart/form-data': nil)
      end

      # Returns a string containing the error message attached to the +method+ on the +object+ if one exists.
      # This error message is wrapped in a <tt>DIV</tt> tag, which can be extended to include a +prepend_text+ and/or +append_text+
      # (to properly explain the error), and a +css_class+ to style it accordingly. +object+ should either be the name of an instance variable or
      # the actual object. As an example, let's say you have a model
      # +post+ that has an error message on the +title+ attribute:
      #
      #   <%= error_message_on "post", "title" %> =>
      #     <div class="formError">can't be empty</div>
      #
      #   <%= error_message_on @post, "title" %> =>
      #     <div class="formError">can't be empty</div>
      #
      #   <%= error_message_on "post", "title", "Title simply ", " (or it won't work).", "inputError" %> =>
      #     <div class="inputError">Title simply can't be empty (or it won't work).</div>
      def error_message_on(object, method, prepend_text = "", append_text = "", css_class = "formError")
        if (obj = (object.respond_to?(:errors) ? object : instance_variable_get("@#{object}"))) &&
          (errors = obj.errors.on(method))
          content_tag("div", "#{prepend_text}#{errors.is_a?(Array) ? errors.first : errors}#{append_text}", :class => css_class)
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
      # * <tt>header_tag</tt> - Used for the header of the error div (default: h2)
      # * <tt>id</tt> - The id of the error div (default: errorExplanation)
      # * <tt>class</tt> - The class of the error div (default: errorExplanation)
      # * <tt>object</tt> - The object (or array of objects) for which to display errors, if you need to escape the instance variable convention
      # * <tt>object_name</tt> - The object name to use in the header, or any text that you prefer. If <tt>object_name</tt> is not set, the name of the first object will be used.
      # * <tt>header_message</tt> - The message in the header of the error div.  Pass +nil+ or an empty string to avoid the header message altogether. (default: X errors prohibited this object from being saved)
      # * <tt>message</tt> - The explanation message after the header message and before the error list.  Pass +nil+ or an empty string to avoid the explanation message altogether.  (default: There were problems with the following fields:)
      #
      # To specify the display for one object, you simply provide its name as a parameter.  For example, for the +User+ model:
      # 
      #   error_messages_for 'user'
      #
      # To specify more than one object, you simply list them; optionally, you can add an extra +object_name+ parameter, which
      # will be the name used in the header message.
      #
      #   error_messages_for 'user_common', 'user', :object_name => 'user'
      #
      # If the objects cannot be located as instance variables, you can add an extra +object+ paremeter which gives the actual
      # object (or array of objects to use)
      #
      #   error_messages_for 'user', :object => @question.user
      #
      # NOTE: This is a pre-packaged presentation of the errors with embedded strings and a certain HTML structure. If what
      # you need is significantly different from the default presentation, it makes plenty of sense to access the object.errors
      # instance yourself and set it up. View the source of this method to see how easy it is.
      def error_messages_for(*params)
        options = params.extract_options!.symbolize_keys
        if object = options.delete(:object)
          objects = [object].flatten
        else
          objects = params.collect {|object_name| instance_variable_get("@#{object_name}") }.compact
        end
        count   = objects.inject(0) {|sum, object| sum + object.errors.count }
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
          options[:header_message] = "#{pluralize(count, 'error')} prohibited this #{options[:object_name].to_s.gsub('_', ' ')} from being saved" unless options.include?(:header_message)
          options[:message] ||= 'There were problems with the following fields:' unless options.include?(:message)
          error_messages = objects.map {|object| object.errors.full_messages.map {|msg| content_tag(:li, msg) } }

          contents = ''
          contents << content_tag(options[:header_tag] || :h2, options[:header_message]) unless options[:header_message].blank?
          contents << content_tag(:p, options[:message]) unless options[:message].blank?
          contents << content_tag(:ul, error_messages)

          content_tag(:div, contents, html)
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

    class InstanceTag #:nodoc:
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

      alias_method :tag_without_error_wrapping, :tag
      def tag(name, options)
        if object.respond_to?("errors") && object.errors.respond_to?("on")
          error_wrapping(tag_without_error_wrapping(name, options), object.errors.on(@method_name))
        else
          tag_without_error_wrapping(name, options)
        end
      end

      alias_method :content_tag_without_error_wrapping, :content_tag
      def content_tag(name, value, options)
        if object.respond_to?("errors") && object.errors.respond_to?("on")
          error_wrapping(content_tag_without_error_wrapping(name, value, options), object.errors.on(@method_name))
        else
          content_tag_without_error_wrapping(name, value, options)
        end
      end

      alias_method :to_date_select_tag_without_error_wrapping, :to_date_select_tag
      def to_date_select_tag(options = {})
        if object.respond_to?("errors") && object.errors.respond_to?("on")
          error_wrapping(to_date_select_tag_without_error_wrapping(options), object.errors.on(@method_name))
        else
          to_date_select_tag_without_error_wrapping(options)
        end
      end

      alias_method :to_datetime_select_tag_without_error_wrapping, :to_datetime_select_tag
      def to_datetime_select_tag(options = {})
        if object.respond_to?("errors") && object.errors.respond_to?("on")
            error_wrapping(to_datetime_select_tag_without_error_wrapping(options), object.errors.on(@method_name))
          else
            to_datetime_select_tag_without_error_wrapping(options)
        end
      end

      alias_method :to_time_select_tag_without_error_wrapping, :to_time_select_tag
      def to_time_select_tag(options = {})
        if object.respond_to?("errors") && object.errors.respond_to?("on")
          error_wrapping(to_time_select_tag_without_error_wrapping(options), object.errors.on(@method_name))
        else
          to_time_select_tag_without_error_wrapping(options)
        end
      end

      def error_wrapping(html_tag, has_error)
        has_error ? Base.field_error_proc.call(html_tag, self) : html_tag
      end

      def error_message
        object.errors.on(@method_name)
      end

      def column_type
        object.send("column_for_attribute", @method_name).type
      end
    end
  end
end

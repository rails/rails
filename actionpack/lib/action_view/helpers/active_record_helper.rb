require 'cgi'
require File.dirname(__FILE__) + '/form_helper'

module ActionView
  class Base
    @@field_error_proc = Proc.new{ |html_tag, instance| "<div class=\"fieldWithErrors\">#{html_tag}</div>" }
    cattr_accessor :field_error_proc
  end

  module Helpers
    # The Active Record Helper makes it easier to create forms for records kept in instance variables. The most far-reaching is the form
    # method that creates a complete form for all the basic content types of the record (not associations or aggregations, though). This
    # is a great of making the record quickly available for editing, but likely to prove lackluster for a complicated real-world form.
    # In that case, it's better to use the input method and the specialized form methods in link:classes/ActionView/Helpers/FormHelper.html
    module ActiveRecordHelper
      # Returns a default input tag for the type of object returned by the method. Example
      # (title is a VARCHAR column and holds "Hello World"):
      #   input("post", "title") =>
      #     <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      def input(record_name, method, options = {})
        InstanceTag.new(record_name, method, self).to_tag(options)
      end

      # Returns an entire form with input tags and everything for a specified Active Record object. Example
      # (post is a new record that has a title using VARCHAR and a body using TEXT):
      #   form("post") =>
      #     <form action='/post/create' method='post'>
      #       <p>
      #         <label for="post_title">Title</label><br />
      #         <input id="post_title" name="post[title]" size="30" type="text" value="Hello World" />
      #       </p>
      #       <p>
      #         <label for="post_body">Body</label><br />
      #         <textarea cols="40" id="post_body" name="post[body]" rows="20">
      #           Back to the hill and over it again!
      #         </textarea>
      #       </p>
      #       <input type='submit' value='Create' />
      #     </form>
      #
      # It's possible to specialize the form builder by using a different action name and by supplying another
      # block renderer. Example (entry is a new record that has a message attribute using VARCHAR):
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

      # Returns a string containing the error message attached to the +method+ on the +object+, if one exists.
      # This error message is wrapped in a DIV tag, which can be specialized to include both a +prepend_text+ and +append_text+
      # to properly introduce the error and a +css_class+ to style it accordingly. Examples (post has an error message
      # "can't be empty" on the title attribute):
      #
      #   <%= error_message_on "post", "title" %> =>
      #     <div class="formError">can't be empty</div>
      #
      #   <%= error_message_on "post", "title", "Title simply ", " (or it won't work)", "inputError" %> =>
      #     <div class="inputError">Title simply can't be empty (or it won't work)</div>
      def error_message_on(object, method, prepend_text = "", append_text = "", css_class = "formError")
        if errors = instance_variable_get("@#{object}").errors.on(method)
          content_tag("div", "#{prepend_text}#{errors.is_a?(Array) ? errors.first : errors}#{append_text}", :class => css_class)
        end
      end

      # Returns a string with a div containing all of the error messages for the objects located as instance variables by the names
      # given.  If more than one object is specified, the errors for the objects are displayed in the order that the object names are
      # provided.
      #
      # This div can be tailored by the following options:
      #
      # * <tt>header_tag</tt> - Used for the header of the error div (default: h2)
      # * <tt>id</tt> - The id of the error div (default: errorExplanation)
      # * <tt>class</tt> - The class of the error div (default: errorExplanation)
      # * <tt>object_name</tt> - The object name to use in the header, or
      # any text that you prefer. If <tt>object_name</tt> is not set, the name of
      # the first object will be used.
      #
      # Specifying one object:
      # 
      #   error_messages_for 'user'
      #
      # Specifying more than one object (and using the name 'user' in the
      # header as the <tt>object_name</tt> instead of 'user_common'):
      #
      #   error_messages_for 'user_common', 'user', :object_name => 'user'
      #
      # NOTE: This is a pre-packaged presentation of the errors with embedded strings and a certain HTML structure. If what
      # you need is significantly different from the default presentation, it makes plenty of sense to access the object.errors
      # instance yourself and set it up. View the source of this method to see how easy it is.
      def error_messages_for(*params)
        options = params.last.is_a?(Hash) ? params.pop.symbolize_keys : {}
        objects = params.collect {|object_name| instance_variable_get("@#{object_name}") }.compact
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
          header_message = "#{pluralize(count, 'error')} prohibited this #{(options[:object_name] || params.first).to_s.gsub('_', ' ')} from being saved"
          error_messages = objects.map {|object| object.errors.full_messages.map {|msg| content_tag(:li, msg) } }
          content_tag(:div,
            content_tag(options[:header_tag] || :h2, header_message) <<
              content_tag(:p, 'There were problems with the following fields:') <<
              content_tag(:ul, error_messages),
            html
          )
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

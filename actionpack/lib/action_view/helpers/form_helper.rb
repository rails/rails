require 'cgi'
require File.dirname(__FILE__) + '/date_helper'

module ActionView
  module Helpers
    # Provides a set of methods for working with forms and especially forms related to objects assigned to the template.
    # The following is an example of a complete form for a person object that works for both creates and updates built
    # with all the form helpers. The <tt>@person</tt> object was assigned by an action on the controller:
    #   <form action="save_person" method="post">
    #     Name:           
    #     <%= text_field "person", "name", "size" => 20 %>
    #
    #     Password:       
    #     <%= password_field "person", "password", "maxsize" => 20 %>
    #
    #     Single?:
    #     <%= check_box "person", "single" %>
    #
    #     Description:
    #     <%= text_area "person", "description", "cols" => 20 %>
    #
    #     <input type="submit" value="Save">
    #   </form>
    #
    # ...is compiled to:
    #
    #   <form action="save_person" method="post">
    #     Name:           
    #     <input type="text" id="person_name" name="person[name]" 
    #       size="20" value="<%= @person.name %>" />
    #
    #     Password:       
    #     <input type="password" id="person_password" name="person[password]" 
    #       size="20" maxsize="20" value="<%= @person.password %>" />
    #
    #     Single?:
    #     <input type="checkbox" id="person_single" name="person[single] value="1" />
    #
    #     Description:
    #     <textarea cols="20" rows="40" id="person_description" name="person[description]">
    #       <%= @person.description %>
    #     </textarea>
    #
    #     <input type="submit" value="Save">
    #   </form>    
    #
    # There's also methods for helping to build form tags in link:classes/ActionView/Helpers/FormOptionsHelper.html, 
    # link:classes/ActionView/Helpers/DateHelper.html, and link:classes/ActionView/Helpers/ActiveRecordHelper.html
    module FormHelper
      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # Examples (call, result):
      #   text_field("post", "title", "size" => 20)
      #     <input type="text" id="post_title" name="post[title]" size="20" value="#{@post.title}" />
      def text_field(object, method, options = {}) 
        InstanceTag.new(object, method, binding).to_input_field_tag("text", options)
      end

      # Works just like text_field, but returns a input tag of the "password" type instead.
      def password_field(object, method, options = {})
        InstanceTag.new(object, method, binding).to_input_field_tag("password", options)
      end

      # Works just like text_field, but returns a input tag of the "hidden" type instead.
      def hidden_field(object, method, options = {})
        InstanceTag.new(object, method, binding).to_input_field_tag("hidden", options)
      end

      # Returns a textarea opening and closing tag set tailored for accessing a specified attribute (identified by +method+)
      # on an object assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # Example (call, result):
      #   text_area("post", "body", "cols" => 20, "rows" => 40)
      #     <textarea cols="20" rows="40" id="post_body" name="post[body]">
      #       #{@post.body}
      #     </textarea>
      def text_area(object, method, options = {})
        InstanceTag.new(object, method, binding).to_text_area_tag(options)
      end
      
      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). It's intended that +method+ returns an integer and if that
      # integer is above zero, then the checkbox is checked. Additional options on the input tag can be passed as a
      # hash with +options+. The +value+ defaults to 1, which is convenient for boolean values. 
      #
      # Example (call, result). Imagine that @post.validated? returns 1:
      #   check_box("post", "validated")
      #     <input type="checkbox" id="post_validate" name="post[validated] value="1" checked="checked" />
      def check_box(object, method, options = {}, value = "1")
        InstanceTag.new(object, method, binding).to_check_box_tag(options, value)
      end
    end

    class InstanceTag #:nodoc:
      DEFAULT_FIELD_OPTIONS     = { "size" => 30 } unless const_defined?("DEFAULT_FIELD_OPTIONS")
      DEFAULT_TEXT_AREA_OPTIONS = { "wrap" => "virtual", "cols" => 40, "rows" => 20 } unless const_defined?("DEFAULT_TEXT_AREA_OPTIONS")

      def initialize(object_name, method_name, tag_binding)
        @object_name, @method_name = object_name, method_name
        @binding = tag_binding
      end
      
      def to_input_field_tag(field_type, options = {})
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        options.merge!({ "size" => options["maxlength"]}) if options["maxlength"] && !options["size"]
        options.merge!({ "type" =>  field_type, "id" => tag_id, "name" => tag_name, "value" => escaped_value })
        html_tag("input", options)
      end
      
      def to_text_area_tag(options = {})
        options = DEFAULT_TEXT_AREA_OPTIONS.merge(options)
        options.merge!({ "id" => tag_id, "name" => tag_name })
        html_tag("textarea", options, true, value)
      end

      def to_check_box_tag(options = {}, checked_value = "1")
        options.merge!({"checked" => "checked"}) if !value.nil? && value > 0
        options.merge!({ "type" => "checkbox", "id" => tag_id, "name" => tag_name, "value" => checked_value })
        html_tag("input", options)
      end

      def to_date_tag()
        defaults = { "discard_type" => true }
        date     = value || Date.today
        options  = Proc.new { |position| defaults.update({ :prefix => "#{@object_name}[#{@method_name}(#{position}i)]" }) }

        html_day_select(date, options.call(3)) +
        html_month_select(date, options.call(2)) + 
        html_year_select(date, options.call(1))
      end

      private
        def html_tag(name, options, has_content = false, content = nil)
          html_tag  = "<#{name}"
          html_tag << tag_options(options)
          html_tag << (has_content ? ">#{content}</#{name}>" : " />")
        end

        def tag_name
          "#{@object_name}[#{@method_name}]"
        end

        def tag_id
          "#{@object_name}_#{@method_name}"
        end

        def tag_options(options)
          " " + options.collect { |pair| "#{pair.first}=\"#{pair.last}\"" }.sort.join(" ") unless options.empty?
        end

        def object
          eval "@#{@object_name}", @binding
        end
        
        def value
          object.send(@method_name) unless object.nil?
        end

        def escaped_value
          CGI.escapeHTML(value.to_s)
        end
    end
  end
end
require 'cgi'
require File.dirname(__FILE__) + '/date_helper'
require File.dirname(__FILE__) + '/tag_helper'

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
    # If the helper is being used to generate a repetitive sequence of similar form elements, for example in a partial
    # used by render_collection_of_partials, the "index" option may come in handy. Example:
    #
    #   <%= text_field "person", "name", "index" => 1 %>
    #
    # becomes
    # 
    #   <input type="text" id="person_1_name" name="person[1][name]" value="<%= @person.name %>" />
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
        InstanceTag.new(object, method, self).to_input_field_tag("text", options)
      end

      # Works just like text_field, but returns a input tag of the "password" type instead.
      def password_field(object, method, options = {})
        InstanceTag.new(object, method, self).to_input_field_tag("password", options)
      end

      # Works just like text_field, but returns a input tag of the "hidden" type instead.
      def hidden_field(object, method, options = {})
        InstanceTag.new(object, method, self).to_input_field_tag("hidden", options)
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
        InstanceTag.new(object, method, self).to_text_area_tag(options)
      end
      
      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). It's intended that +method+ returns an integer and if that
      # integer is above zero, then the checkbox is checked. Additional options on the input tag can be passed as a
      # hash with +options+. The +checked_value+ defaults to 1 while the default +unchecked_value+
      # is set to 0 which is convenient for boolean values. Usually unchecked checkboxes don't post anything. 
      # We work around this problem by adding a hidden value with the same name as the checkbox.
      #
      # Example (call, result). Imagine that @post.validated? returns 1:
      #   check_box("post", "validated")
      #     <input type="checkbox" id="post_validate" name="post[validated] value="1" checked="checked" />
      #     <input name="post[validated]" type="hidden" value="0" />
      #
      # Example (call, result). Imagine that @puppy.gooddog returns no:
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #     <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog] value="yes" />
      #     <input name="puppy[gooddog]" type="hidden" value="no" />
      def check_box(object, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object, method, self).to_check_box_tag(options, checked_value, unchecked_value)
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked. Additional options on the input tag can be passed as a
      # hash with +options+. 
      # Example (call, result). Imagine that @post.category returns "rails":
      #   radio_button("post", "category", "rails")
      #   radio_button("post", "category", "java")
      #     <input type="radio" id="post_category" name="post[category] value="rails" checked="checked" />
      #     <input type="radio" id="post_category" name="post[category] value="java" />
      #     
      def radio_button(object, method, tag_value, options = {})
        InstanceTag.new(object, method, self).to_radio_button_tag(tag_value, options)
      end
    end

    class InstanceTag #:nodoc:
      include Helpers::TagHelper

      attr_reader :method_name, :object_name
      
      DEFAULT_FIELD_OPTIONS     = { "size" => 30 } unless const_defined?("DEFAULT_FIELD_OPTIONS")
      DEFAULT_TEXT_AREA_OPTIONS = { "wrap" => "virtual", "cols" => 40, "rows" => 20 } unless const_defined?("DEFAULT_TEXT_AREA_OPTIONS")

      def initialize(object_name, method_name, template_object, local_binding = nil)
        @object_name, @method_name = object_name, method_name
        @template_object, @local_binding = template_object, local_binding
        if @object_name.sub!(/\[\]$/,"")
          @auto_index = @template_object.instance_variable_get("@#{Regexp.last_match.pre_match}").id
        end
      end
      
      def to_input_field_tag(field_type, options = {})
        html_options = DEFAULT_FIELD_OPTIONS.merge(options)
        html_options.merge!({ "size" => options["maxlength"]}) if options["maxlength"] && !options["size"]
        html_options.delete("size") if field_type == "hidden"
        html_options.merge!({ "type" =>  field_type})
        html_options.merge!({ "value" => value_before_type_cast }) unless options["value"]
        add_default_name_and_id(html_options)
        tag("input", html_options)
      end

      def to_radio_button_tag(tag_value, options={})
        html_options = DEFAULT_FIELD_OPTIONS.merge(options)
        html_options.merge!({ "checked" => "checked" }) if value == tag_value
        html_options.merge!({ "type" => "radio", "value"=> tag_value.to_s })
                       
        add_default_name_and_id(html_options)
        tag("input", html_options)
      end
      
      def to_text_area_tag(options = {})
        options = DEFAULT_TEXT_AREA_OPTIONS.merge(options)
        add_default_name_and_id(options)
        content_tag("textarea", html_escape(value_before_type_cast), options)
      end

      def to_check_box_tag(options = {}, checked_value = "1", unchecked_value = "0")
        options.merge!({ "checked" => "checked" }) if !value.nil? && ((value.is_a?(TrueClass) || value.is_a?(FalseClass)) ? value : value.to_i > 0)
        options.merge!({ "type" => "checkbox", "value" => checked_value })
        add_default_name_and_id(options)
        tag("input", options) << tag("input", ({ "name" => options['name'], "type" => "hidden", "value" => unchecked_value }))
      end

      def to_date_tag()
        defaults = { "discard_type" => true }
        date     = value || Date.today
        options  = Proc.new { |position| defaults.update({ :prefix => "#{@object_name}[#{@method_name}(#{position}i)]" }) }

        html_day_select(date, options.call(3)) +
        html_month_select(date, options.call(2)) + 
        html_year_select(date, options.call(1))
      end

      def to_boolean_select_tag(options = {})
        add_default_name_and_id(options)
        tag_text = "<select"
        tag_text << tag_options(options)
        tag_text << "><option value=\"false\""
        tag_text << " selected" if value == false
        tag_text << ">False</option><option value=\"true\""
        tag_text << " selected" if value
        tag_text << ">True</option></select>"
      end

      def object
        @template_object.instance_variable_get "@#{@object_name}"
      end

      def value
        object.send(@method_name) unless object.nil?
      end

      def value_before_type_cast
        unless object.nil?
          object.respond_to?(@method_name + "_before_type_cast") ? 
            object.send(@method_name + "_before_type_cast") :
            object.send(@method_name)
        end
      end

      private
        def add_default_name_and_id(options)
          if options.has_key? "index"
            options['name'] = tag_name_with_index(options["index"]) unless options.has_key? "name"
            options['id'] = tag_id_with_index(options["index"]) unless options.has_key? "id"
            options.delete("index")
          elsif @auto_index
            options['name'] = tag_name_with_index(@auto_index) unless options.has_key? "name"
            options['id'] = tag_id_with_index(@auto_index) unless options.has_key? "id"
          else
            options['name'] = tag_name unless options.has_key? "name"
            options['id'] = tag_id unless options.has_key? "id"
          end
        end
				
        def tag_name
          "#{@object_name}[#{@method_name}]"
        end
				
        def tag_name_with_index(index)
          "#{@object_name}[#{index}][#{@method_name}]"
        end

        def tag_id
          "#{@object_name}_#{@method_name}"
        end

        def tag_id_with_index(index)
          "#{@object_name}_#{index}_#{@method_name}"
        end
    end
  end
end

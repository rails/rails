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
    #     <input type="checkbox" id="person_single" name="person[single]" value="1" />
    #
    #     Description:
    #     <textarea cols="20" rows="40" id="person_description" name="person[description]">
    #       <%= @person.description %>
    #     </textarea>
    #
    #     <input type="submit" value="Save">
    #   </form>
    #
    # If the object name contains square brackets the id for the object will be inserted. Example:
    #
    #   <%= text_field "person[]", "name" %> 
    # 
    # ...becomes:
    #
    #   <input type="text" id="person_<%= @person.id %>_name" name="person[<%= @person.id %>][name]" value="<%= @person.name %>" />
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
      # Creates a form and a scope around a specific model object, which is then used as a base for questioning about
      # values for the fields. Examples:
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= f.text_area :biography %>
      #     Admin?    : <%= f.check_box :admin %>
      #   <% end %>
      #
      # Worth noting is that the form_for tag is called in a ERb evaluation block, not a ERb output block. So that's <tt><% %></tt>, 
      # not <tt><%= %></tt>. Also worth noting is that the form_for yields a form_builder object, in this example as f, which emulates
      # the API for the stand-alone FormHelper methods, but without the object name. So instead of <tt>text_field :person, :name</tt>,
      # you get away with <tt>f.text_field :name</tt>. 
      #
      # That in itself is a modest increase in comfort. The big news is that form_for allows us to more easily escape the instance
      # variable convention, so while the stand-alone approach would require <tt>text_field :person, :name, :object => person</tt> 
      # to work with local variables instead of instance ones, the form_for calls remain the same. You simply declare once with 
      # <tt>:person, person</tt> and all subsequent field calls save <tt>:person</tt> and <tt>:object => person</tt>.
      #
      # Also note that form_for doesn't create an exclusive scope. It's still possible to use both the stand-alone FormHelper methods
      # and methods from FormTagHelper. Example:
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= text_area :person, :biography %>
      #     Admin?    : <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      #
      # Note: This also works for the methods in FormOptionHelper and DateHelper that are designed to work with an object as base.
      # Like collection_select and datetime_select.
      #
      # Html attributes for the form tag can be given as :html => {...}. Example:
      #     
      #   <% form_for :person, @person, :html => {:id => 'person_form'} do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also build forms using a customized FormBuilder class. Subclass FormBuilder and override or define some more helpers,
      # then use your custom builder like so:
      #   
      #   <% form_for :person, @person, :url => { :action => "update" }, :builder => LabellingFormBuilder do |f| %>
      #     <%= f.text_field :first_name %>
      #     <%= f.text_field :last_name %>
      #     <%= text_area :person, :biography %>
      #     <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      # 
      # In many cases you will want to wrap the above in another helper, such as:
      #
      #   def labelled_form_for(name, object, options, &proc)
      #     form_for(name, object, options.merge(:builder => LabellingFormBuiler), &proc)
      #   end
      #
      def form_for(object_name, *args, &proc)
        raise ArgumentError, "Missing block" unless block_given?
        options = args.last.is_a?(Hash) ? args.pop : {}
        concat(form_tag(options.delete(:url) || {}, options.delete(:html) || {}), proc.binding)
        fields_for(object_name, *(args << options), &proc)
        concat('</form>', proc.binding)
      end

      # Creates a scope around a specific model object like form_for, but doesn't create the form tags themselves. This makes
      # fields_for suitable for specifying additional model objects in the same form. Example:
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #     
      #     <% fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #   <% end %>
      #
      # Note: This also works for the methods in FormOptionHelper and DateHelper that are designed to work with an object as base.
      # Like collection_select and datetime_select.
      def fields_for(object_name, *args, &block)
        raise ArgumentError, "Missing block" unless block_given?
        options = args.last.is_a?(Hash) ? args.pop : {}
        object  = args.first

        builder = options[:builder] || ActionView::Base.default_form_builder
        yield builder.new(object_name, object, self, options, block)
      end

      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # Examples (call, result):
      #   text_field("post", "title", "size" => 20)
      #     <input type="text" id="post_title" name="post[title]" size="20" value="#{@post.title}" />
      def text_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("text", options)
      end

      # Works just like text_field, but returns an input tag of the "password" type instead.
      def password_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("password", options)
      end

      # Works just like text_field, but returns an input tag of the "hidden" type instead.
      def hidden_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("hidden", options)
      end

      # Works just like text_field, but returns an input tag of the "file" type instead, which won't have a default value.
      def file_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("file", options)
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
      def text_area(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_text_area_tag(options)
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
      #     <input type="checkbox" id="post_validate" name="post[validated]" value="1" checked="checked" />
      #     <input name="post[validated]" type="hidden" value="0" />
      #
      # Example (call, result). Imagine that @puppy.gooddog returns no:
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #     <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #     <input name="puppy[gooddog]" type="hidden" value="no" />
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_check_box_tag(options, checked_value, unchecked_value)
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked. Additional options on the input tag can be passed as a
      # hash with +options+.
      # Example (call, result). Imagine that @post.category returns "rails":
      #   radio_button("post", "category", "rails")
      #   radio_button("post", "category", "java")
      #     <input type="radio" id="post_category" name="post[category]" value="rails" checked="checked" />
      #     <input type="radio" id="post_category" name="post[category]" value="java" />
      #
      def radio_button(object_name, method, tag_value, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_radio_button_tag(tag_value, options)
      end
    end

    class InstanceTag #:nodoc:
      include Helpers::TagHelper

      attr_reader :method_name, :object_name

      DEFAULT_FIELD_OPTIONS     = { "size" => 30 }.freeze unless const_defined?(:DEFAULT_FIELD_OPTIONS)
      DEFAULT_RADIO_OPTIONS     = { }.freeze unless const_defined?(:DEFAULT_RADIO_OPTIONS)
      DEFAULT_TEXT_AREA_OPTIONS = { "cols" => 40, "rows" => 20 }.freeze unless const_defined?(:DEFAULT_TEXT_AREA_OPTIONS)
      DEFAULT_DATE_OPTIONS = { :discard_type => true }.freeze unless const_defined?(:DEFAULT_DATE_OPTIONS)

      def initialize(object_name, method_name, template_object, local_binding = nil, object = nil)
        @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
        @template_object, @local_binding = template_object, local_binding
        @object = object
        if @object_name.sub!(/\[\]$/,"")
          if object ||= @template_object.instance_variable_get("@#{Regexp.last_match.pre_match}") and object.respond_to?(:id_before_type_cast)
            @auto_index = object.id_before_type_cast
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to id_before_type_cast: #{object.inspect}"
          end
        end
      end

      def to_input_field_tag(field_type, options = {})
        options = options.stringify_keys
        options["size"] ||= options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"]
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        if field_type == "hidden"
          options.delete("size")
        end
        options["type"] = field_type
        options["value"] ||= value_before_type_cast(object) unless field_type == "file"
        add_default_name_and_id(options)
        tag("input", options)
      end

      def to_radio_button_tag(tag_value, options = {})
        options = DEFAULT_RADIO_OPTIONS.merge(options.stringify_keys)
        options["type"]     = "radio"
        options["value"]    = tag_value
        if options.has_key?("checked")
          cv = options.delete "checked"
          checked = cv == true || cv == "checked"
        else
          checked = self.class.radio_button_checked?(value(object), tag_value)
        end
        options["checked"]  = "checked" if checked
        pretty_tag_value    = tag_value.to_s.gsub(/\s/, "_").gsub(/\W/, "").downcase
        options["id"]     ||= defined?(@auto_index) ?             
          "#{@object_name}_#{@auto_index}_#{@method_name}_#{pretty_tag_value}" :
          "#{@object_name}_#{@method_name}_#{pretty_tag_value}"
        add_default_name_and_id(options)
        tag("input", options)
      end

      def to_text_area_tag(options = {})
        options = DEFAULT_TEXT_AREA_OPTIONS.merge(options.stringify_keys)
        add_default_name_and_id(options)

        if size = options.delete("size")
          options["cols"], options["rows"] = size.split("x")
        end

        content_tag("textarea", html_escape(options.delete('value') || value_before_type_cast(object)), options)
      end

      def to_check_box_tag(options = {}, checked_value = "1", unchecked_value = "0")
        options = options.stringify_keys
        options["type"]     = "checkbox"
        options["value"]    = checked_value
        if options.has_key?("checked")
          cv = options.delete "checked"
          checked = cv == true || cv == "checked"
        else
          checked = self.class.check_box_checked?(value(object), checked_value)
        end
        options["checked"] = "checked" if checked
        add_default_name_and_id(options)
        tag("input", options) << tag("input", "name" => options["name"], "type" => "hidden", "value" => unchecked_value)
      end

      def to_date_tag()
        defaults = DEFAULT_DATE_OPTIONS.dup
        date     = value(object) || Date.today
        options  = Proc.new { |position| defaults.merge(:prefix => "#{@object_name}[#{@method_name}(#{position}i)]") }
        html_day_select(date, options.call(3)) +
        html_month_select(date, options.call(2)) +
        html_year_select(date, options.call(1))
      end

      def to_boolean_select_tag(options = {})
        options = options.stringify_keys
        add_default_name_and_id(options)
        value = value(object)
        tag_text = "<select"
        tag_text << tag_options(options)
        tag_text << "><option value=\"false\""
        tag_text << " selected" if value == false
        tag_text << ">False</option><option value=\"true\""
        tag_text << " selected" if value
        tag_text << ">True</option></select>"
      end
      
      def to_content_tag(tag_name, options = {})
        content_tag(tag_name, value(object), options)
      end
      
      def object
        @object || @template_object.instance_variable_get("@#{@object_name}")
      end

      def value(object)
        self.class.value(object, @method_name)
      end

      def value_before_type_cast(object)
        self.class.value_before_type_cast(object, @method_name)
      end
      
      class << self
        def value(object, method_name)
          object.send method_name unless object.nil?
        end
        
        def value_before_type_cast(object, method_name)
          unless object.nil?
            object.respond_to?(method_name + "_before_type_cast") ?
            object.send(method_name + "_before_type_cast") :
            object.send(method_name)
          end
        end
        
        def check_box_checked?(value, checked_value)
          case value
          when TrueClass, FalseClass
            value
          when NilClass
            false
          when Integer
            value != 0
          when String
            value == checked_value
          else
            value.to_i != 0
          end
        end
        
        def radio_button_checked?(value, checked_value)
          value.to_s == checked_value.to_s
        end
      end

      private
        def add_default_name_and_id(options)
          if options.has_key?("index")
            options["name"] ||= tag_name_with_index(options["index"])
            options["id"]   ||= tag_id_with_index(options["index"])
            options.delete("index")
          elsif defined?(@auto_index)
            options["name"] ||= tag_name_with_index(@auto_index)
            options["id"]   ||= tag_id_with_index(@auto_index)
          else
            options["name"] ||= tag_name
            options["id"]   ||= tag_id
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

    class FormBuilder #:nodoc:
      # The methods which wrap a form helper call.
      class_inheritable_accessor :field_helpers
      self.field_helpers = (FormHelper.instance_methods - ['form_for'])

      attr_accessor :object_name, :object, :options

      def initialize(object_name, object, template, options, proc)
        @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc        
      end
      
      (field_helpers - %w(check_box radio_button)).each do |selector|
        src = <<-end_src
          def #{selector}(method, options = {})
            @template.send(#{selector.inspect}, @object_name, method, options.merge(:object => @object))
          end
        end_src
        class_eval src, __FILE__, __LINE__
      end
      
      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.check_box(@object_name, method, options.merge(:object => @object), checked_value, unchecked_value)
      end
      
      def radio_button(method, tag_value, options = {})
        @template.radio_button(@object_name, method, tag_value, options.merge(:object => @object))
      end
    end
  end

  class Base
    cattr_accessor :default_form_builder
    self.default_form_builder = ::ActionView::Helpers::FormBuilder
  end
end

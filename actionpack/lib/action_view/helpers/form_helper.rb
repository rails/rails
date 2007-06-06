require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    # Form helpers are designed to make working with models much easier than just standard html elements by
    # providing a set of methods for creating forms based on your models.  This helper generates the HTML for forms,
    # providing a method for each sort of input (e.g., text, password, select, and so on).  When the form is 
    # submitted (i.e., when the user hits the submit button or <tt>form.submit</tt> is called via JavaScript), the form 
    # inputs will be bundled into the <tt>params</tt> object and passed back to the controller.
    #
    # There are two types of form helpers: those that specifically work with model attributes and those that don't.  
    # This helper deals with those that work with model attributes; to see an example of form helpers that don't work
    # with model attributes, check the ActionView::Helpers::FormTagHelper documentation.
    #
    # The core method of this helper, form_for, gives you the ability to create a form for a model instance; 
    # for example, let's say that you have a model <tt>Person</tt> and want to create a new instance of it:
    #
    #     # Note: a @person variable will have been created in the controller. 
    #     # For example: @person = Person.new
    #     <% form_for :person, @person, :url => { :action => "create" } do |f| %>
    #       <%= f.text_field :first_name %>
    #       <%= f.text_field :last_name %>
    #       <%= submit_tag 'Create' %>
    #     <% end %>
    #
    # The HTML generated for this would be:
    #
    #     <form action="/persons/create" method="post">
    #       <input id="person_first_name" name="person[first_name]" size="30" type="text" />
    #       <input id="person_last_name" name="person[last_name]" size="30" type="text" />
    #       <input name="commit" type="submit" value="Create" />
    #     </form>
    #
    # The <tt>params</tt> object created when this form is submitted would look like:
    #
    #     {"action"=>"create", "controller"=>"persons", "person"=>{"first_name"=>"William", "last_name"=>"Smith"}}
    # 
    # The params hash has a nested <tt>person</tt> value, which can therefore be accessed with <tt>params[:person]</tt> in the controller.
    # If were editing/updating an instance (e.g., <tt>Person.find(1)</tt> rather than <tt>Person.new</tt> in the controller), the objects
    # attribute values are filled into the form (e.g., the <tt>person_first_name</tt> field would have that person's first name in it).
    #    
    # If the object name contains square brackets the id for the object will be inserted. For example:
    #
    #   <%= text_field "person[]", "name" %> 
    # 
    # ...will generate the following ERb.
    #
    #   <input type="text" id="person_<%= @person.id %>_name" name="person[<%= @person.id %>][name]" value="<%= @person.name %>" />
    #
    # If the helper is being used to generate a repetitive sequence of similar form elements, for example in a partial
    # used by <tt>render_collection_of_partials</tt>, the <tt>index</tt> option may come in handy. Example:
    #
    #   <%= text_field "person", "name", "index" => 1 %>
    #
    # ...becomes...
    #
    #   <input type="text" id="person_1_name" name="person[1][name]" value="<%= @person.name %>" />
    #
    # There are also methods for helping to build form tags in link:classes/ActionView/Helpers/FormOptionsHelper.html,
    # link:classes/ActionView/Helpers/DateHelper.html, and link:classes/ActionView/Helpers/ActiveRecordHelper.html
    module FormHelper
      # Creates a form and a scope around a specific model object that is used as a base for questioning about
      # values for the fields.  
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= f.text_area :biography %>
      #     Admin?    : <%= f.check_box :admin %>
      #   <% end %>
      #
      # Worth noting is that the form_for tag is called in a ERb evaluation block, not an ERb output block. So that's <tt><% %></tt>, 
      # not <tt><%= %></tt>. Also worth noting is that form_for yields a <tt>form_builder</tt> object, in this example as <tt>f</tt>, which emulates
      # the API for the stand-alone FormHelper methods, but without the object name. So instead of <tt>text_field :person, :name</tt>,
      # you get away with <tt>f.text_field :name</tt>. 
      #
      # Even further, the form_for method allows you to more easily escape the instance variable convention.  So while the stand-alone 
      # approach would require <tt>text_field :person, :name, :object => person</tt> 
      # to work with local variables instead of instance ones, the form_for calls remain the same. You simply declare once with 
      # <tt>:person, person</tt> and all subsequent field calls save <tt>:person</tt> and <tt>:object => person</tt>.
      #
      # Also note that form_for doesn't create an exclusive scope. It's still possible to use both the stand-alone FormHelper methods
      # and methods from FormTagHelper. For example:
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= text_area :person, :biography %>
      #     Admin?    : <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      #
      # Note: This also works for the methods in FormOptionHelper and DateHelper that are designed to work with an object as base.
      # Like FormOptionHelper#collection_select and DateHelper#datetime_select.
      #
      # HTML attributes for the form tag can be given as :html => {...}. For example:
      #     
      #   <% form_for :person, @person, :html => {:id => 'person_form'} do |f| %>
      #     ...
      #   <% end %>
      #
      # The above form will then have the <tt>id</tt> attribute with the value </tt>person_form</tt>, which you can then
      # style with CSS or manipulate with JavaScript.
      #
      # === Relying on record identification
      #
      # In addition to manually configuring the form_for call, you can also rely on record identification, which will use
      # the conventions and named routes of that approach. Examples:
      #
      #   <% form_for(@post) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% form_for :post, @post, :url => post_path(@post), :html => { :method => :put, :class => "edit_post", :id => "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # And for new records:
      #
      #   <% form_for(Post.new) do |f| %>
      #     ...
      #   <% end %>
      #
      # This will expand to be the same as:
      #
      #   <% form_for :post, @post, :url => posts_path, :html => { :class => "new_post", :id => "new_post" } do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also overwrite the individual conventions, like this:
      #
      #   <% form_for(@post, :url => super_post_path(@post)) do |f| %>
      #     ...
      #   <% end %>
      #
      # === Customized form builders
      #
      # You can also build forms using a customized FormBuilder class. Subclass FormBuilder and override or define some more helpers,
      # then use your custom builder.  For example, let's say you made a helper to automatically add labels to form inputs.
      #   
      #   <% form_for :person, @person, :url => { :action => "update" }, :builder => LabellingFormBuilder do |f| %>
      #     <%= f.text_field :first_name %>
      #     <%= f.text_field :last_name %>
      #     <%= text_area :person, :biography %>
      #     <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      # 
      # In many cases you will want to wrap the above in another helper, so you could do something like the following:
      #
      #   def labelled_form_for(name, object, options, &proc)
      #     form_for(name, object, options.merge(:builder => LabellingFormBuiler), &proc)
      #   end
      #
      # If you don't need to attach a form to a model instance, then check out FormTagHelper#form_tag.
      def form_for(record_or_name_or_array, *args, &proc)
        raise ArgumentError, "Missing block" unless block_given?

        options = args.last.is_a?(Hash) ? args.pop : {}

        case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
        when Array
          object = record_or_name_or_array.last
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          # apply_form_for_options!(object, options, *record_or_name_or_array)
          apply_form_for_options!(record_or_name_or_array, options)
          args.unshift object
        else
          object = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!([ object ], options)
          args.unshift object
        end

        concat(form_tag(options.delete(:url) || {}, options.delete(:html) || {}), proc.binding)
        fields_for(object_name, *(args << options), &proc)
        concat('</form>', proc.binding)
      end

      def apply_form_for_options!(object_or_array, options) #:nodoc:
        object = object_or_array.is_a?(Array) ? object_or_array.last : object_or_array
        
        html_options =
          if object.respond_to?(:new_record?) && object.new_record?
            { :class  => dom_class(object, :new),  :id => dom_id(object), :method => :post }
          else
            { :class  => dom_class(object, :edit), :id => dom_id(object, :edit), :method => :put }
          end

        options[:html] ||= {}
        options[:html].reverse_merge!(html_options)
        options[:url] ||= polymorphic_path(object_or_array)
      end

      # Creates a scope around a specific model object like form_for, but doesn't create the form tags themselves. This makes
      # fields_for suitable for specifying additional model objects in the same form:
      #
      # ==== Examples
      #   <% form_for :person, @person, :url => { :action => "update" } do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #     
      #     <% fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #   <% end %>
      #
      # Note: This also works for the methods in FormOptionHelper and DateHelper that are designed to work with an object as base,
      # like FormOptionHelper#collection_select and DateHelper#datetime_select.
      def fields_for(object_name, *args, &block)
        raise ArgumentError, "Missing block" unless block_given?
        options = args.last.is_a?(Hash) ? args.pop : {}
        object  = args.first

        builder = options[:builder] || ActionView::Base.default_form_builder
        yield builder.new(object_name, object, self, options, block)
      end

      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.  These options will be tagged onto the html as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   text_field(:post, :title, :size => 20)
      #   # => <input type="text" id="post_title" name="post[title]" size="20" value="#{@post.title}" />
      #
      #   text_field(:post, :title, :class => "create_input")
      #   # => <input type="text" id="post_title" name="post[title]" value="#{@post.title}" class="create_input" />
      #
      #   text_field(:session, :user, :onchange => "if $('session[user]').value == 'admin' { alert('Your login can not be admin!'); }")
      #   # => <input type="text" id="session_user" name="session[user]" value="#{@session.user}" onchange = "if $('session[user]').value == 'admin' { alert('Your login can not be admin!'); }"/>
      #
      #   text_field(:snippet, :code, :size => 20, :class => 'code_input')
      #   # => <input type="text" id="snippet_code" name="snippet[code]" size="20" value="#{@snippet.code}" class="code_input" />
      #
      def text_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("text", options)
      end

      # Returns an input tag of the "password" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.  These options will be tagged onto the html as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   password_field(:login, :pass, :size => 20)
      #   # => <input type="text" id="login_pass" name="login[pass]" size="20" value="#{@login.pass}" />
      #
      #   password_field(:account, :secret, :class => "form_input")
      #   # => <input type="text" id="account_secret" name="account[secret]" value="#{@account.secret}" class="form_input" />
      #
      #   password_field(:user, :password, :onchange => "if $('user[password]').length > 30 { alert('Your password needs to be shorter!'); }")
      #   # => <input type="text" id="user_password" name="user[password]" value="#{@user.password}" onchange = "if $('user[password]').length > 30 { alert('Your password needs to be shorter!'); }"/>
      #
      #   password_field(:account, :pin, :size => 20, :class => 'form_input')
      #   # => <input type="text" id="account_pin" name="account[pin]" size="20" value="#{@account.pin}" class="form_input" />
      #
      def password_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("password", options)
      end

      # Returns a hidden input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.  These options will be tagged onto the html as an html element attribute as in the example
      # shown.
      #
      # ==== Examples 
      #   hidden_field(:signup, :pass_confirm)
      #   # => <input type="hidden" id="signup_pass_confirm" name="signup[pass_confirm]" value="#{@signup.pass_confirm}" />
      #
      #   hidden_field(:post, :tag_list)
      #   # => <input type="hidden" id="post_tag_list" name="post[tag_list]" value="#{@post.tag_list}" />
      #
      #   hidden_field(:user, :token)
      #   # => <input type="hidden" id="user_token" name="user[token]" value="#{@user.token}" />   
      def hidden_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("hidden", options)
      end

      # Returns an file upload input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.  These options will be tagged onto the html as an html element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   file_field(:user, :avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   file_field(:post, :attached, :accept => 'text/html')
      #   # => <input type="file" id="post_attached" name="post[attached]" />
      #
      #   file_field(:attachment, :file, :class => 'file_input')
      #   # => <input type="file" id="attachment_file" name="attachment[file]" class="file_input" />
      #
      def file_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_input_field_tag("file", options)
      end

      # Returns a textarea opening and closing tag set tailored for accessing a specified attribute (identified by +method+)
      # on an object assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # ==== Examples
      #   text_area(:post, :body, :cols => 20, :rows => 40)
      #   # => <textarea cols="20" rows="40" id="post_body" name="post[body]">
      #   #      #{@post.body}
      #   #    </textarea>
      #
      #   text_area(:comment, :text, :size => "20x30")
      #   # => <textarea cols="20" rows="30" id="comment_text" name="comment[text]">
      #   #      #{@comment.text}
      #   #    </textarea>
      #
      #   text_area(:application, :notes, :cols => 40, :rows => 15, :class => 'app_input')
      #   # => <textarea cols="40" rows="15" id="application_notes" name="application[notes]" class="app_input">
      #   #      #{@application.notes}
      #   #    </textarea>
      #
      #   text_area(:entry, :body, :size => "20x20", :disabled => 'disabled')
      #   # => <textarea cols="20" rows="20" id="entry_body" name="entry[body]" disabled="disabled">
      #   #      #{@entry.body}
      #   #    </textarea>
      def text_area(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_text_area_tag(options)
      end

      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). It's intended that +method+ returns an integer and if that
      # integer is above zero, then the checkbox is checked. Additional options on the input tag can be passed as a
      # hash with +options+. The +checked_value+ defaults to 1 while the default +unchecked_value+
      # is set to 0 which is convenient for boolean values. Since HTTP standards say that unchecked checkboxes don't post anything,
      # we add a hidden value with the same name as the checkbox as a work around.
      #
      # ==== Examples 
      #   # Let's say that @post.validated? is 1:
      #   check_box("post", "validated")
      #   # => <input type="checkbox" id="post_validate" name="post[validated]" value="1" checked="checked" />
      #   #    <input name="post[validated]" type="hidden" value="0" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #   # => <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #   #    <input name="puppy[gooddog]" type="hidden" value="no" />
      #
      #   check_box("eula", "accepted", {}, "yes", "no", :class => 'eula_check')
      #   # => <input type="checkbox" id="eula_accepted" name="eula[accepted]" value="no" />
      #   #    <input name="eula[accepted]" type="hidden" value="no" />
      #
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object_name, method, self, nil, options.delete(:object)).to_check_box_tag(options, checked_value, unchecked_value)
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked. Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # ==== Examples
      #   # Let's say that @post.category returns "rails":
      #   radio_button("post", "category", "rails")
      #   radio_button("post", "category", "java")
      #   # => <input type="radio" id="post_category" name="post[category]" value="rails" checked="checked" />
      #   #    <input type="radio" id="post_category" name="post[category]" value="java" />
      #
      #   radio_button("user", "receive_newsletter", "yes")
      #   radio_button("user", "receive_newsletter", "no")
      #   # => <input type="radio" id="user_receive_newsletter" name="user[receive_newsletter]" value="yes" />
      #   #    <input type="radio" id="user_receive_newsletter" name="user[receive_newsletter]" value="no" checked="checked" />
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
        options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
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
          options["cols"], options["rows"] = size.split("x") if size.respond_to?(:split)
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
            options["name"] ||= tag_name + (options.has_key?('multiple') ? '[]' : '')
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
          "#{sanitized_object_name}_#{@method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{@method_name}"
        end

        def sanitized_object_name
          @object_name.gsub(/[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
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
      
      (field_helpers - %w(check_box radio_button fields_for)).each do |selector|
        src = <<-end_src
          def #{selector}(method, options = {})
            @template.send(#{selector.inspect}, @object_name, method, options.merge(:object => @object))
          end
        end_src
        class_eval src, __FILE__, __LINE__
      end

      def fields_for(name, *args, &block)
        name = "#{object_name}[#{name}]"
        @template.fields_for(name, *args, &block)
      end

      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.check_box(@object_name, method, options.merge(:object => @object), checked_value, unchecked_value)
      end
      
      def radio_button(method, tag_value, options = {})
        @template.radio_button(@object_name, method, tag_value, options.merge(:object => @object))
      end
      
      def error_message_on(method, prepend_text = "", append_text = "", css_class = "formError")
        @template.error_message_on(@object_name, method, prepend_text, append_text, css_class)
      end      

      def error_messages(options = {})
        @template.error_messages_for(@object_name, options)
      end
      
      def submit(value = "Save changes", options = {})
        @template.submit_tag(value, options.reverse_merge(:id => "#{object_name}_submit"))
      end
    end
  end

  class Base
    cattr_accessor :default_form_builder
    self.default_form_builder = ::ActionView::Helpers::FormBuilder
  end
end

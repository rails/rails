require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_tag_helper'

module ActionView
  module Helpers
    # Form helpers are designed to make working with models much easier
    # compared to using just standard HTML elements by providing a set of
    # methods for creating forms based on your models. This helper generates
    # the HTML for forms, providing a method for each sort of input
    # (e.g., text, password, select, and so on). When the form is submitted
    # (i.e., when the user hits the submit button or <tt>form.submit</tt> is
    # called via JavaScript), the form inputs will be bundled into the
    # <tt>params</tt> object and passed back to the controller.
    #
    # There are two types of form helpers: those that specifically work with
    # model attributes and those that don't. This helper deals with those that
    # work with model attributes; to see an example of form helpers that don't
    # work with model attributes, check the ActionView::Helpers::FormTagHelper
    # documentation.
    #
    # The core method of this helper, form_for, gives you the ability to create
    # a form for a model instance; for example, let's say that you have a model
    # <tt>Person</tt> and want to create a new instance of it:
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
    # If you are using a partial for your form fields, you can use this shortcut:
    #
    #     <% form_for :person, @person, :url => { :action => "create" } do |f| %>
    #       <%= render :partial => f %>
    #       <%= submit_tag 'Create' %>
    #     <% end %>
    #
    # This example will render the <tt>people/_form</tt> partial, setting a
    # local variable called <tt>form</tt> which references the yielded
    # FormBuilder. The <tt>params</tt> object created when this form is
    # submitted would look like:
    #
    #     {"action"=>"create", "controller"=>"persons", "person"=>{"first_name"=>"William", "last_name"=>"Smith"}}
    #
    # The params hash has a nested <tt>person</tt> value, which can therefore
    # be accessed with <tt>params[:person]</tt> in the controller. If were
    # editing/updating an instance (e.g., <tt>Person.find(1)</tt> rather than
    # <tt>Person.new</tt> in the controller), the objects attribute values are
    # filled into the form (e.g., the <tt>person_first_name</tt> field would
    # have that person's first name in it).
    #
    # If the object name contains square brackets the id for the object will be
    # inserted. For example:
    #
    #   <%= text_field "person[]", "name" %>
    #
    # ...will generate the following ERb.
    #
    #   <input type="text" id="person_<%= @person.id %>_name" name="person[<%= @person.id %>][name]" value="<%= @person.name %>" />
    #
    # If the helper is being used to generate a repetitive sequence of similar
    # form elements, for example in a partial used by
    # <tt>render_collection_of_partials</tt>, the <tt>index</tt> option may
    # come in handy. Example:
    #
    #   <%= text_field "person", "name", "index" => 1 %>
    #
    # ...becomes...
    #
    #   <input type="text" id="person_1_name" name="person[1][name]" value="<%= @person.name %>" />
    #
    # An <tt>index</tt> option may also be passed to <tt>form_for</tt> and
    # <tt>fields_for</tt>.  This automatically applies the <tt>index</tt> to
    # all the nested fields.
    #
    # There are also methods for helping to build form tags in
    # link:classes/ActionView/Helpers/FormOptionsHelper.html,
    # link:classes/ActionView/Helpers/DateHelper.html, and
    # link:classes/ActionView/Helpers/ActiveRecordHelper.html
    module FormHelper
      # Creates a form and a scope around a specific model object that is used
      # as a base for questioning about values for the fields.
      #
      # Rails provides succinct resource-oriented form generation with +form_for+
      # like this:
      #
      #   <% form_for @offer do |f| %>
      #     <%= f.label :version, 'Version' %>:
      #     <%= f.text_field :version %><br />
      #     <%= f.label :author, 'Author' %>:
      #     <%= f.text_field :author %><br />
      #   <% end %>
      #
      # There, +form_for+ is able to generate the rest of RESTful form
      # parameters based on introspection on the record, but to understand what
      # it does we need to dig first into the alternative generic usage it is
      # based upon.
      #
      # === Generic form_for
      #
      # The generic way to call +form_for+ yields a form builder around a
      # model:
      #
      #   <% form_for :person, :url => { :action => "update" } do |f| %>
      #     <%= f.error_messages %>
      #     First name: <%= f.text_field :first_name %><br />
      #     Last name : <%= f.text_field :last_name %><br />
      #     Biography : <%= f.text_area :biography %><br />
      #     Admin?    : <%= f.check_box :admin %><br />
      #   <% end %>
      #
      # There, the first argument is a symbol or string with the name of the
      # object the form is about, and also the name of the instance variable
      # the object is stored in.
      #
      # The form builder acts as a regular form helper that somehow carries the
      # model. Thus, the idea is that
      #
      #   <%= f.text_field :first_name %>
      #
      # gets expanded to
      #
      #   <%= text_field :person, :first_name %>
      #
      # If the instance variable is not <tt>@person</tt> you can pass the actual
      # record as the second argument:
      #
      #   <% form_for :person, person, :url => { :action => "update" } do |f| %>
      #     ...
      #   <% end %>
      #
      # In that case you can think
      #
      #   <%= f.text_field :first_name %>
      #
      # gets expanded to
      #
      #   <%= text_field :person, :first_name, :object => person %>
      #
      # You can even display error messages of the wrapped model this way:
      #
      #   <%= f.error_messages %>
      #
      # In any of its variants, the rightmost argument to +form_for+ is an
      # optional hash of options:
      #
      # * <tt>:url</tt> - The URL the form is submitted to. It takes the same
      #   fields you pass to +url_for+ or +link_to+. In particular you may pass
      #   here a named route directly as well. Defaults to the current action.
      # * <tt>:html</tt> - Optional HTML attributes for the form tag.
      #
      # Worth noting is that the +form_for+ tag is called in a ERb evaluation
      # block, not an ERb output block. So that's <tt><% %></tt>, not
      # <tt><%= %></tt>.
      #
      # Also note that +form_for+ doesn't create an exclusive scope. It's still
      # possible to use both the stand-alone FormHelper methods and methods
      # from FormTagHelper. For example:
      #
      #   <% form_for :person, @person, :url => { :action => "update" } do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= text_area :person, :biography %>
      #     Admin?    : <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      #
      # This also works for the methods in FormOptionHelper and DateHelper that
      # are designed to work with an object as base, like
      # FormOptionHelper#collection_select and DateHelper#datetime_select.
      #
      # === Resource-oriented style
      #
      # As we said above, in addition to manually configuring the +form_for+
      # call, you can rely on automated resource identification, which will use
      # the conventions and named routes of that approach. This is the
      # preferred way to use +form_for+ nowadays.
      #
      # For example, if <tt>@post</tt> is an existing record you want to edit
      #
      #   <% form_for @post do |f| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <% form_for :post, @post, :url => post_path(@post), :html => { :method => :put, :class => "edit_post", :id => "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # And for new records
      #
      #   <% form_for(Post.new) do |f| %>
      #     ...
      #   <% end %>
      #
      # expands to
      #
      #   <% form_for :post, Post.new, :url => posts_path, :html => { :class => "new_post", :id => "new_post" } do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also overwrite the individual conventions, like this:
      #
      #   <% form_for(@post, :url => super_post_path(@post)) do |f| %>
      #     ...
      #   <% end %>
      #
      # And for namespaced routes, like +admin_post_url+:
      #
      #   <% form_for([:admin, @post]) do |f| %>
      #    ...
      #   <% end %>
      #
      # === Customized form builders
      #
      # You can also build forms using a customized FormBuilder class. Subclass
      # FormBuilder and override or define some more helpers, then use your
      # custom builder. For example, let's say you made a helper to
      # automatically add labels to form inputs.
      #
      #   <% form_for :person, @person, :url => { :action => "update" }, :builder => LabellingFormBuilder do |f| %>
      #     <%= f.text_field :first_name %>
      #     <%= f.text_field :last_name %>
      #     <%= text_area :person, :biography %>
      #     <%= check_box_tag "person[admin]", @person.company.admin? %>
      #   <% end %>
      #
      # In this case, if you use this:
      #
      #   <%= render :partial => f %>
      #
      # The rendered template is <tt>people/_labelling_form</tt> and the local
      # variable referencing the form builder is called
      # <tt>labelling_form</tt>.
      #
      # The custom FormBuilder class is automatically merged with the options
      # of a nested fields_for call, unless it's explicitely set.
      #
      # In many cases you will want to wrap the above in another helper, so you
      # could do something like the following:
      #
      #   def labelled_form_for(record_or_name_or_array, *args, &proc)
      #     options = args.extract_options!
      #     form_for(record_or_name_or_array, *(args << options.merge(:builder => LabellingFormBuilder)), &proc)
      #   end
      #
      # If you don't need to attach a form to a model instance, then check out
      # FormTagHelper#form_tag.
      def form_for(record_or_name_or_array, *args, &proc)
        raise ArgumentError, "Missing block" unless block_given?

        options = args.extract_options!

        case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
        when Array
          object = record_or_name_or_array.last
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!(record_or_name_or_array, options)
          args.unshift object
        else
          object = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
          apply_form_for_options!([object], options)
          args.unshift object
        end

        concat(form_tag(options.delete(:url) || {}, options.delete(:html) || {}))
        fields_for(object_name, *(args << options), &proc)
        concat('</form>'.html_safe)
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

      # Creates a scope around a specific model object like form_for, but
      # doesn't create the form tags themselves. This makes fields_for suitable
      # for specifying additional model objects in the same form.
      #
      # === Generic Examples
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <% fields_for @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #   <% end %>
      #
      # ...or if you have an object that needs to be represented as a different
      # parameter, like a Client that acts as a Person:
      #
      #   <% fields_for :person, @client do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # ...or if you don't have an object, just a name of the parameter:
      #
      #   <% fields_for :person do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # Note: This also works for the methods in FormOptionHelper and
      # DateHelper that are designed to work with an object as base, like
      # FormOptionHelper#collection_select and DateHelper#datetime_select.
      #
      # === Nested Attributes Examples
      #
      # When the object belonging to the current scope has a nested attribute
      # writer for a certain attribute, fields_for will yield a new scope
      # for that attribute. This allows you to create forms that set or change
      # the attributes of a parent object and its associations in one go.
      #
      # Nested attribute writers are normal setter methods named after an
      # association. The most common way of defining these writers is either
      # with +accepts_nested_attributes_for+ in a model definition or by
      # defining a method with the proper name. For example: the attribute
      # writer for the association <tt>:address</tt> is called
      # <tt>address_attributes=</tt>.
      #
      # Whether a one-to-one or one-to-many style form builder will be yielded
      # depends on whether the normal reader method returns a _single_ object
      # or an _array_ of objects.
      #
      # ==== One-to-one
      #
      # Consider a Person class which returns a _single_ Address from the
      # <tt>address</tt> reader method and responds to the
      # <tt>address_attributes=</tt> writer method:
      #
      #   class Person
      #     def address
      #       @address
      #     end
      #
      #     def address_attributes=(attributes)
      #       # Process the attributes hash
      #     end
      #   end
      #
      # This model can now be used with a nested fields_for, like so:
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% person_form.fields_for :address do |address_fields| %>
      #       Street  : <%= address_fields.text_field :street %>
      #       Zip code: <%= address_fields.text_field :zip_code %>
      #     <% end %>
      #   <% end %>
      #
      # When address is already an association on a Person you can use
      # +accepts_nested_attributes_for+ to define the writer method for you:
      #
      #   class Person < ActiveRecord::Base
      #     has_one :address
      #     accepts_nested_attributes_for :address
      #   end
      #
      # If you want to destroy the associated model through the form, you have
      # to enable it first using the <tt>:allow_destroy</tt> option for
      # +accepts_nested_attributes_for+:
      #
      #   class Person < ActiveRecord::Base
      #     has_one :address
      #     accepts_nested_attributes_for :address, :allow_destroy => true
      #   end
      #
      # Now, when you use a form element with the <tt>_destroy</tt> parameter,
      # with a value that evaluates to +true+, you will destroy the associated
      # model (eg. 1, '1', true, or 'true'):
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% person_form.fields_for :address do |address_fields| %>
      #       ...
      #       Delete: <%= address_fields.check_box :_destroy %>
      #     <% end %>
      #   <% end %>
      #
      # ==== One-to-many
      #
      # Consider a Person class which returns an _array_ of Project instances
      # from the <tt>projects</tt> reader method and responds to the
      # <tt>projects_attributes=</tt> writer method:
      #
      #   class Person
      #     def projects
      #       [@project1, @project2]
      #     end
      #
      #     def projects_attributes=(attributes)
      #       # Process the attributes hash
      #     end
      #   end
      #
      # This model can now be used with a nested fields_for. The block given to
      # the nested fields_for call will be repeated for each instance in the
      # collection:
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% person_form.fields_for :projects do |project_fields| %>
      #       <% if project_fields.object.active? %>
      #         Name: <%= project_fields.text_field :name %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      #
      # It's also possible to specify the instance to be used:
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% @person.projects.each do |project| %>
      #       <% if project.active? %>
      #         <% person_form.fields_for :projects, project do |project_fields| %>
      #           Name: <%= project_fields.text_field :name %>
      #         <% end %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      #
      # Or a collection to be used:
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% person_form.fields_for :projects, @active_projects do |project_fields| %>
      #       Name: <%= project_fields.text_field :name %>
      #     <% end %>
      #   <% end %>
      #
      # When projects is already an association on Person you can use
      # +accepts_nested_attributes_for+ to define the writer method for you:
      #
      #   class Person < ActiveRecord::Base
      #     has_many :projects
      #     accepts_nested_attributes_for :projects
      #   end
      #
      # If you want to destroy any of the associated models through the
      # form, you have to enable it first using the <tt>:allow_destroy</tt>
      # option for +accepts_nested_attributes_for+:
      #
      #   class Person < ActiveRecord::Base
      #     has_many :projects
      #     accepts_nested_attributes_for :projects, :allow_destroy => true
      #   end
      #
      # This will allow you to specify which models to destroy in the
      # attributes hash by adding a form element for the <tt>_destroy</tt>
      # parameter with a value that evaluates to +true+
      # (eg. 1, '1', true, or 'true'):
      #
      #   <% form_for @person, :url => { :action => "update" } do |person_form| %>
      #     ...
      #     <% person_form.fields_for :projects do |project_fields| %>
      #       Delete: <%= project_fields.check_box :_destroy %>
      #     <% end %>
      #   <% end %>
      def fields_for(record_or_name_or_array, *args, &block)
        raise ArgumentError, "Missing block" unless block_given?
        options = args.extract_options!

        case record_or_name_or_array
        when String, Symbol
          object_name = record_or_name_or_array
          object = args.first
        else
          object = record_or_name_or_array
          object_name = ActionController::RecordIdentifier.singular_class_name(object)
        end

        builder = options[:builder] || ActionView::Base.default_form_builder
        yield builder.new(object_name, object, self, options, block)
      end

      # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). The text of label will default to the attribute name unless a translation
      # is found in the current I18n locale (through views.labels.<modelname>.<attribute>) or you specify it explicitly. 
      # Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
      # onto the HTML as an HTML element attribute as in the example shown, except for the <tt>:value</tt> option, which is designed to
      # target labels for radio_button tags (where the value is used in the ID of the input tag).
      #
      # ==== Examples
      #   label(:post, :title)
      #   # => <label for="post_title">Title</label>
      #
      #   You can localize your labels based on model and attribute names.
      #   For example you can define the following in your locale (e.g. en.yml)
      #
      #   views:
      #     labels:
      #       post:
      #         body: "Write your entire text here"
      #
      #   Which then will result in
      #
      #   label(:post, :body)
      #   # => <label for="post_body">Write your entire text here</label>
      #
      #   Localization can also be based purely on the translation of the attribute-name like this:
      #
      #   activerecord:
      #     attribute:
      #       post:
      #         cost: "Total cost"
      #
      #   label(:post, :cost)
      #   # => <label for="post_cost">Total cost</label>
      #
      #   label(:post, :title, "A short title")
      #   # => <label for="post_title">A short title</label>
      #
      #   label(:post, :title, "A short title", :class => "title_label")
      #   # => <label for="post_title" class="title_label">A short title</label>
      #
      #   label(:post, :privacy, "Public Post", :value => "public")
      #   # => <label for="post_privacy_public">Public Post</label>
      #
      def label(object_name, method, text = nil, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_label_tag(text, options)
      end

      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
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
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("text", options)
      end

      # Returns an input tag of the "password" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
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
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("password", options)
      end

      # Returns a hidden input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
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
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("hidden", options)
      end

      # Returns an file upload input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
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
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("file", options)
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
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_text_area_tag(options)
      end

      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). This object must be an instance object (@object) and not a local object.
      # It's intended that +method+ returns an integer and if that integer is above zero, then the checkbox is checked. 
      # Additional options on the input tag can be passed as a hash with +options+. The +checked_value+ defaults to 1 
      # while the default +unchecked_value+ is set to 0 which is convenient for boolean values.
      #
      # ==== Gotcha
      #
      # The HTML specification says unchecked check boxes are not successful, and
      # thus web browsers do not send them. Unfortunately this introduces a gotcha:
      # if an Invoice model has a +paid+ flag, and in the form that edits a paid
      # invoice the user unchecks its check box, no +paid+ parameter is sent. So,
      # any mass-assignment idiom like
      #
      #   @invoice.update_attributes(params[:invoice])
      #
      # wouldn't update the flag.
      #
      # To prevent this the helper generates a hidden field with the same name as
      # the checkbox after the very check box. So, the client either sends only the
      # hidden field (representing the check box is unchecked), or both fields.
      # Since the HTML specification says key/value pairs have to be sent in the
      # same order they appear in the form and Rails parameters extraction always
      # gets the first occurrence of any given key, that works in ordinary forms.
      #
      # Unfortunately that workaround does not work when the check box goes
      # within an array-like parameter, as in
      #
      #   <% fields_for "project[invoice_attributes][]", invoice, :index => nil do |form| %>
      #     <%= form.check_box :paid %>
      #     ...
      #   <% end %>
      #
      # because parameter name repetition is precisely what Rails seeks to distinguish
      # the elements of the array.
      #
      # ==== Examples
      #   # Let's say that @post.validated? is 1:
      #   check_box("post", "validated")
      #   # => <input type="checkbox" id="post_validated" name="post[validated]" value="1" />
      #   #    <input name="post[validated]" type="hidden" value="0" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #   # => <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #   #    <input name="puppy[gooddog]" type="hidden" value="no" />
      #
      #   check_box("eula", "accepted", { :class => 'eula_check' }, "yes", "no")
      #   # => <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
      #   #    <input name="eula[accepted]" type="hidden" value="no" />
      #
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_check_box_tag(options, checked_value, unchecked_value)
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked.
      #
      # To force the radio button to be checked pass <tt>:checked => true</tt> in the
      # +options+ hash. You may pass HTML options there as well.
      #
      # ==== Examples
      #   # Let's say that @post.category returns "rails":
      #   radio_button("post", "category", "rails")
      #   radio_button("post", "category", "java")
      #   # => <input type="radio" id="post_category_rails" name="post[category]" value="rails" checked="checked" />
      #   #    <input type="radio" id="post_category_java" name="post[category]" value="java" />
      #
      #   radio_button("user", "receive_newsletter", "yes")
      #   radio_button("user", "receive_newsletter", "no")
      #   # => <input type="radio" id="user_receive_newsletter_yes" name="user[receive_newsletter]" value="yes" />
      #   #    <input type="radio" id="user_receive_newsletter_no" name="user[receive_newsletter]" value="no" checked="checked" />
      def radio_button(object_name, method, tag_value, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_radio_button_tag(tag_value, options)
      end
    end

    class InstanceTag #:nodoc:
      include Helpers::TagHelper, Helpers::FormTagHelper

      attr_reader :method_name, :object_name

      DEFAULT_FIELD_OPTIONS     = { "size" => 30 }.freeze unless const_defined?(:DEFAULT_FIELD_OPTIONS)
      DEFAULT_RADIO_OPTIONS     = { }.freeze unless const_defined?(:DEFAULT_RADIO_OPTIONS)
      DEFAULT_TEXT_AREA_OPTIONS = { "cols" => 40, "rows" => 20 }.freeze unless const_defined?(:DEFAULT_TEXT_AREA_OPTIONS)

      def initialize(object_name, method_name, template_object, object = nil)
        @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
        @template_object = template_object
        @object = object
        if @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
          if (object ||= @template_object.instance_variable_get("@#{Regexp.last_match.pre_match}")) && object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end
      end

      def to_label_tag(text = nil, options = {})
        options = options.stringify_keys
        tag_value = options.delete("value")
        name_and_id = options.dup
        name_and_id["id"] = name_and_id["for"]
        add_default_name_and_id_for_value(tag_value, name_and_id)
        options.delete("index")
        options["for"] ||= name_and_id["id"]

        content = if text.blank?
          i18n_label = I18n.t("helpers.label.#{object_name}.#{method_name}", :default => "")
          i18n_label if i18n_label.present?
        else
          text.to_s
        end

        content ||= if object && object.class.respond_to?(:human_attribute_name)
          object.class.human_attribute_name(method_name)
        end

        content ||= method_name.humanize

        label_tag(name_and_id["id"], content, options)
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
        options["value"] &&= html_escape(options["value"])
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
        add_default_name_and_id_for_value(tag_value, options)
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
        hidden = tag("input", "name" => options["name"], "type" => "hidden", "value" => options['disabled'] && checked ? checked_value : unchecked_value)
        checkbox = tag("input", options)
        (hidden + checkbox).html_safe
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
      rescue NameError
        # As @object_name may contain the nested syntax (item[subobject]) we
        # need to fallback to nil.
        nil
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
          when Array
            value.include?(checked_value)
          else
            value.to_i != 0
          end
        end

        def radio_button_checked?(value, checked_value)
          value.to_s == checked_value.to_s
        end
      end

      private
        def add_default_name_and_id_for_value(tag_value, options)
          unless tag_value.nil?
            pretty_tag_value = tag_value.to_s.gsub(/\s/, "_").gsub(/\W/, "").downcase
            specified_id = options["id"]
            add_default_name_and_id(options)
            options["id"] += "_#{pretty_tag_value}" unless specified_id
          else
            add_default_name_and_id(options)
          end
        end

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
          "#{@object_name}[#{sanitized_method_name}]"
        end

        def tag_name_with_index(index)
          "#{@object_name}[#{index}][#{sanitized_method_name}]"
        end

        def tag_id
          "#{sanitized_object_name}_#{sanitized_method_name}"
        end

        def tag_id_with_index(index)
          "#{sanitized_object_name}_#{index}_#{sanitized_method_name}"
        end

        def sanitized_object_name
          @sanitized_object_name ||= @object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").sub(/_$/, "")
        end

        def sanitized_method_name
          @sanitized_method_name ||= @method_name.sub(/\?$/,"")
        end
    end

    class FormBuilder #:nodoc:
      # The methods which wrap a form helper call.
      class_inheritable_accessor :field_helpers
      self.field_helpers = (FormHelper.instance_methods - ['form_for'])

      attr_accessor :object_name, :object, :options

      def initialize(object_name, object, template, options, proc)
        @nested_child_index = {}
        @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc
        @default_options = @options ? @options.slice(:index) : {}
        if @object_name.to_s.match(/\[\]$/)
          if object ||= @template.instance_variable_get("@#{Regexp.last_match.pre_match}") and object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end
      end

      (field_helpers - %w(label check_box radio_button fields_for hidden_field)).each do |selector|
        src, line = <<-end_src, __LINE__ + 1
          def #{selector}(method, options = {})  # def text_field(method, options = {})
            @template.send(                      #   @template.send(
              #{selector.inspect},               #     "text_field",
              @object_name,                      #     @object_name,
              method,                            #     method,
              objectify_options(options))        #     objectify_options(options))
          end                                    # end
        end_src
        class_eval src, __FILE__, line
      end

      def fields_for(record_or_name_or_array, *args, &block)
        if options.has_key?(:index)
          index = "[#{options[:index]}]"
        elsif defined?(@auto_index)
          self.object_name = @object_name.to_s.sub(/\[\]$/,"")
          index = "[#{@auto_index}]"
        else
          index = ""
        end

        if options[:builder]
          args << {} unless args.last.is_a?(Hash)
          args.last[:builder] ||= options[:builder]
        end

        case record_or_name_or_array
        when String, Symbol
          if nested_attributes_association?(record_or_name_or_array)
            return fields_for_with_nested_attributes(record_or_name_or_array, args, block)
          else
            name = "#{object_name}#{index}[#{record_or_name_or_array}]"
          end
        when Array
          object = record_or_name_or_array.last
          name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
          args.unshift(object)
        else
          object = record_or_name_or_array
          name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
          args.unshift(object)
        end

        @template.fields_for(name, *args, &block)
      end

      def label(method, text = nil, options = {})
        @template.label(@object_name, method, text, objectify_options(options))
      end

      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end

      def radio_button(method, tag_value, options = {})
        @template.radio_button(@object_name, method, tag_value, objectify_options(options))
      end
      
      def hidden_field(method, options = {})
        @emitted_hidden_id = true if method == :id
        @template.hidden_field(@object_name, method, objectify_options(options))
      end

      def error_message_on(method, *args)
        @template.error_message_on(@object || @object_name, method, *args)
      end

      def error_messages(options = {})
        @template.error_messages_for(@object_name, objectify_options(options))
      end

      def submit(value = "Save changes", options = {})
        @template.submit_tag(value, options.reverse_merge(:id => "#{object_name}_submit"))
      end

      def emitted_hidden_id?
        @emitted_hidden_id
      end

      private
        def objectify_options(options)
          @default_options.merge(options.merge(:object => @object))
        end

        def nested_attributes_association?(association_name)
          @object.respond_to?("#{association_name}_attributes=")
        end

        def fields_for_with_nested_attributes(association_name, args, block)
          name = "#{object_name}[#{association_name}_attributes]"
          association = args.first

          if association.respond_to?(:new_record?)
            association = [association] if @object.send(association_name).is_a?(Array)
          elsif !association.is_a?(Array)
            association = @object.send(association_name)
          end

          if association.is_a?(Array)
            explicit_child_index = args.last[:child_index] if args.last.is_a?(Hash)
            association.map do |child|
              fields_for_nested_model("#{name}[#{explicit_child_index || nested_child_index(name)}]", child, args, block)
            end.join
          elsif association
            fields_for_nested_model(name, association, args, block)
          end
        end

        def fields_for_nested_model(name, object, args, block)
          if object.new_record?
            @template.fields_for(name, object, *args, &block)
          else
            @template.fields_for(name, object, *args) do |builder|
              block.call(builder)
              @template.concat builder.hidden_field(:id) unless builder.emitted_hidden_id?
            end
          end
        end

        def nested_child_index(name)
          @nested_child_index[name] ||= -1
          @nested_child_index[name] += 1
        end
    end
  end

  class Base
    cattr_accessor :default_form_builder
    self.default_form_builder = ::ActionView::Helpers::FormBuilder
  end
end

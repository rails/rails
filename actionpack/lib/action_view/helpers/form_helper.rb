require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_tag_helper'
require 'action_view/helpers/active_model_helper'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/method_names'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/string/inflections'

module ActionView
  # = Action View Form Helpers
  module Helpers
    # Form helpers are designed to make working with resources much easier
    # compared to using vanilla HTML.
    #
    # Forms for models are created with +form_for+. That method yields a form
    # builder that knows the model the form is about. The form builder is thus
    # able to generate default values for input fields that correspond to model
    # attributes, and also convenient names, IDs, endpoints, etc.
    #
    # Conventions in the generated field names allow controllers to receive form
    # data nicely structured in +params+ with no effort on your side.
    #
    # For example, to create a new person you typically set up a new instance of
    # +Person+ in the <tt>PeopleController#new</tt> action, <tt>@person</tt>, and
    # pass it to +form_for+:
    #
    #   <%= form_for @person do |f| %>
    #     <%= f.label :first_name %>:
    #     <%= f.text_field :first_name %><br />
    #
    #     <%= f.label :last_name %>:
    #     <%= f.text_field :last_name %><br />
    #
    #     <%= f.submit %>
    #   <% end %>
    #
    # The HTML generated for this would be (modulus formatting):
    #
    #   <form action="/people" class="new_person" id="new_person" method="post">
    #     <div style="margin:0;padding:0;display:inline">
    #       <input name="authenticity_token" type="hidden" value="NrOp5bsjoLRuK8IW5+dQEYjKGUJDe7TQoZVvq95Wteg=" />
    #     </div>
    #     <label for="person_first_name">First name</label>:
    #     <input id="person_first_name" name="person[first_name]" size="30" type="text" /><br />
    #
    #     <label for="person_last_name">Last name</label>:
    #     <input id="person_last_name" name="person[last_name]" size="30" type="text" /><br />
    #
    #     <input name="commit" type="submit" value="Create Person" />
    #   </form>
    #
    # As you see, the HTML reflects knowledge about the resource in several spots,
    # like the path the form should be submitted to, or the names of the input fields.
    #
    # In particular, thanks to the conventions followed in the generated field names, the
    # controller gets a nested hash <tt>params[:person]</tt> with the person attributes
    # set in the form. That hash is ready to be passed to <tt>Person.create</tt>:
    #
    #   if @person = Person.create(params[:person])
    #     # success
    #   else
    #     # error handling
    #   end
    #
    # Interestingly, the exact same view code in the previous example can be used to edit
    # a person. If <tt>@person</tt> is an existing record with name "John Smith" and ID 256,
    # the code above as is would yield instead:
    #
    #   <form action="/people/256" class="edit_person" id="edit_person_256" method="post">
    #     <div style="margin:0;padding:0;display:inline">
    #       <input name="_method" type="hidden" value="put" />
    #       <input name="authenticity_token" type="hidden" value="NrOp5bsjoLRuK8IW5+dQEYjKGUJDe7TQoZVvq95Wteg=" />
    #     </div>
    #     <label for="person_first_name">First name</label>:
    #     <input id="person_first_name" name="person[first_name]" size="30" type="text" value="John" /><br />
    #
    #     <label for="person_last_name">Last name</label>:
    #     <input id="person_last_name" name="person[last_name]" size="30" type="text" value="Smith" /><br />
    #
    #     <input name="commit" type="submit" value="Update Person" />
    #   </form>
    #
    # Note that the endpoint, default values, and submit button label are tailored for <tt>@person</tt>.
    # That works that way because the involved helpers know whether the resource is a new record or not,
    # and generate HTML accordingly.
    #
    # The controller would receive the form data again in <tt>params[:person]</tt>, ready to be
    # passed to <tt>Person#update_attributes</tt>:
    #
    #   if @person.update_attributes(params[:person])
    #     # success
    #   else
    #     # error handling
    #   end
    #
    # That's how you typically work with resources.
    module FormHelper
      extend ActiveSupport::Concern

      include FormTagHelper
      include UrlHelper

      # Converts the given object to an ActiveModel compliant one.
      def convert_to_model(object)
        object.respond_to?(:to_model) ? object.to_model : object
      end

      # Creates a form and a scope around a specific model object that is used
      # as a base for questioning about values for the fields.
      #
      # Rails provides succinct resource-oriented form generation with +form_for+
      # like this:
      #
      #   <%= form_for @offer do |f| %>
      #     <%= f.label :version, 'Version' %>:
      #     <%= f.text_field :version %><br />
      #     <%= f.label :author, 'Author' %>:
      #     <%= f.text_field :author %><br />
      #     <%= f.submit %>
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
      #   <%= form_for :person do |f| %>
      #     First name: <%= f.text_field :first_name %><br />
      #     Last name : <%= f.text_field :last_name %><br />
      #     Biography : <%= f.text_area :biography %><br />
      #     Admin?    : <%= f.check_box :admin %><br />
      #     <%= f.submit %>
      #   <% end %>
      #
      # There, the argument is a symbol or string with the name of the
      # object the form is about.
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
      # The rightmost argument to +form_for+ is an
      # optional hash of options:
      #
      # * <tt>:url</tt> - The URL the form is submitted to. It takes the same
      #   fields you pass to +url_for+ or +link_to+. In particular you may pass
      #   here a named route directly as well. Defaults to the current action.
      # * <tt>:namespace</tt> - A namespace for your form to ensure uniqueness of
      #   id attributes on form elements. The namespace attribute will be prefixed
      #   with underscore on the generated HTML id.
      # * <tt>:html</tt> - Optional HTML attributes for the form tag.
      #
      # Also note that +form_for+ doesn't create an exclusive scope. It's still
      # possible to use both the stand-alone FormHelper methods and methods
      # from FormTagHelper. For example:
      #
      #   <%= form_for @person do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= text_area :person, :biography %>
      #     Admin?    : <%= check_box_tag "person[admin]", @person.company.admin? %>
      #     <%= f.submit %>
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
      #   <%= form_for @post do |f| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <%= form_for @post, :as => :post, :url => post_path(@post), :method => :put, :html => { :class => "edit_post", :id => "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # And for new records
      #
      #   <%= form_for(Post.new) do |f| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <%= form_for @post, :as => :post, :url => posts_path, :html => { :class => "new_post", :id => "new_post" } do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also overwrite the individual conventions, like this:
      #
      #   <%= form_for(@post, :url => super_posts_path) do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also set the answer format, like this:
      #
      #   <%= form_for(@post, :format => :json) do |f| %>
      #     ...
      #   <% end %>
      #
      # If you have an object that needs to be represented as a different
      # parameter, like a Person that acts as a Client:
      #
      #   <%= form_for(@person, :as => :client) do |f| %>
      #     ...
      #   <% end %>
      #
      # For namespaced routes, like +admin_post_url+:
      #
      #   <%= form_for([:admin, @post]) do |f| %>
      #    ...
      #   <% end %>
      #
      # If your resource has associations defined, for example, you want to add comments
      # to the document given that the routes are set correctly:
      #
      #   <%= form_for([@document, @comment]) do |f| %>
      #    ...
      #   <% end %>
      #
      # Where <tt>@document = Document.find(params[:id])</tt> and
      # <tt>@comment = Comment.new</tt>.
      #
      # === Setting the method
      #
      # You can force the form to use the full array of HTTP verbs by setting
      #
      #    :method => (:get|:post|:put|:delete)
      #
      # in the options hash. If the verb is not GET or POST, which are natively supported by HTML forms, the
      # form will be set to POST and a hidden input called _method will carry the intended verb for the server
      # to interpret.
      #
      # === Unobtrusive JavaScript
      #
      # Specifying:
      #
      #    :remote => true
      #
      # in the options hash creates a form that will allow the unobtrusive JavaScript drivers to modify its
      # behavior. The expected default behavior is an XMLHttpRequest in the background instead of the regular
      # POST arrangement, but ultimately the behavior is the choice of the JavaScript driver implementor.
      # Even though it's using JavaScript to serialize the form elements, the form submission will work just like
      # a regular submission as viewed by the receiving side (all elements available in <tt>params</tt>).
      #
      # Example:
      #
      #   <%= form_for(@post, :remote => true) do |f| %>
      #     ...
      #   <% end %>
      #
      # The HTML generated for this would be:
      #
      #   <form action='http://www.example.com' method='post' data-remote='true'>
      #     <div style='margin:0;padding:0;display:inline'>
      #       <input name='_method' type='hidden' value='put' />
      #     </div>
      #     ...
      #   </form>
      #
      # === Removing hidden model id's
      #
      # The form_for method automatically includes the model id as a hidden field in the form.
      # This is used to maintain the correlation between the form data and its associated model.
      # Some ORM systems do not use IDs on nested models so in this case you want to be able
      # to disable the hidden id.
      #
      # In the following example the Post model has many Comments stored within it in a NoSQL database,
      # thus there is no primary key for comments.
      #
      # Example:
      #
      #   <%= form_for(@post) do |f| %>
      #     <% f.fields_for(:comments, :include_id => false) do |cf| %>
      #       ...
      #     <% end %>
      #   <% end %>
      #
      # === Customized form builders
      #
      # You can also build forms using a customized FormBuilder class. Subclass
      # FormBuilder and override or define some more helpers, then use your
      # custom builder. For example, let's say you made a helper to
      # automatically add labels to form inputs.
      #
      #   <%= form_for @person, :url => { :action => "create" }, :builder => LabellingFormBuilder do |f| %>
      #     <%= f.text_field :first_name %>
      #     <%= f.text_field :last_name %>
      #     <%= f.text_area :biography %>
      #     <%= f.check_box :admin %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # In this case, if you use this:
      #
      #   <%= render f %>
      #
      # The rendered template is <tt>people/_labelling_form</tt> and the local
      # variable referencing the form builder is called
      # <tt>labelling_form</tt>.
      #
      # The custom FormBuilder class is automatically merged with the options
      # of a nested fields_for call, unless it's explicitly set.
      #
      # In many cases you will want to wrap the above in another helper, so you
      # could do something like the following:
      #
      #   def labelled_form_for(record_or_name_or_array, *args, &block)
      #     options = args.extract_options!
      #     form_for(record_or_name_or_array, *(args << options.merge(:builder => LabellingFormBuilder)), &block)
      #   end
      #
      # If you don't need to attach a form to a model instance, then check out
      # FormTagHelper#form_tag.
      #
      # === Form to external resources
      #
      # When you build forms to external resources sometimes you need to set an authenticity token or just render a form
      # without it, for example when you submit data to a payment gateway number and types of fields could be limited.
      #
      # To set an authenticity token you need to pass an <tt>:authenticity_token</tt> parameter
      #
      #   <%= form_for @invoice, :url => external_url, :authenticity_token => 'external_token' do |f|
      #     ...
      #   <% end %>
      #
      # If you don't want to an authenticity token field be rendered at all just pass <tt>false</tt>:
      #
      #   <%= form_for @invoice, :url => external_url, :authenticity_token => false do |f|
      #     ...
      #   <% end %>
      def form_for(record, options = {}, &block)
        raise ArgumentError, "Missing block" unless block_given?

        options[:html] ||= {}

        case record
        when String, Symbol
          object_name = record
          object      = nil
        else
          object      = record.is_a?(Array) ? record.last : record
          object_name = options[:as] || ActiveModel::Naming.param_key(object)
          apply_form_for_options!(record, options)
        end

        options[:html][:remote] = options.delete(:remote) if options.has_key?(:remote)
        options[:html][:method] = options.delete(:method) if options.has_key?(:method)
        options[:html][:authenticity_token] = options.delete(:authenticity_token)

        builder = options[:parent_builder] = instantiate_builder(object_name, object, options, &block)
        output  = capture(builder, &block)
        default_options = builder.multipart? ? { :multipart => true } : {}
        form_tag(options.delete(:url) || {}, default_options.merge!(options.delete(:html))) { output }
      end

      def apply_form_for_options!(object_or_array, options) #:nodoc:
        object = object_or_array.is_a?(Array) ? object_or_array.last : object_or_array
        object = convert_to_model(object)

        as = options[:as]
        action, method = object.respond_to?(:persisted?) && object.persisted? ? [:edit, :put] : [:new, :post]
        options[:html].reverse_merge!(
          :class  => as ? "#{action}_#{as}" : dom_class(object, action),
          :id     => as ? "#{action}_#{as}" : [options[:namespace], dom_id(object, action)].compact.join("_").presence,
          :method => method
        )

        options[:url] ||= polymorphic_path(object_or_array, :format => options.delete(:format))
      end
      private :apply_form_for_options!

      # Creates a scope around a specific model object like form_for, but
      # doesn't create the form tags themselves. This makes fields_for suitable
      # for specifying additional model objects in the same form.
      #
      # === Generic Examples
      #
      #   <%= form_for @person do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <%= fields_for @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #
      #     <%= f.submit %>
      #   <% end %>
      #
      # ...or if you have an object that needs to be represented as a different
      # parameter, like a Client that acts as a Person:
      #
      #   <%= fields_for :person, @client do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # ...or if you don't have an object, just a name of the parameter:
      #
      #   <%= fields_for :person do |permission_fields| %>
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
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :address do |address_fields| %>
      #       Street  : <%= address_fields.text_field :street %>
      #       Zip code: <%= address_fields.text_field :zip_code %>
      #     <% end %>
      #     ...
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
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :address do |address_fields| %>
      #       ...
      #       Delete: <%= address_fields.check_box :_destroy %>
      #     <% end %>
      #     ...
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
      # Note that the <tt>projects_attributes=</tt> writer method is in fact
      # required for fields_for to correctly identify <tt>:projects</tt> as a
      # collection, and the correct indices to be set in the form markup.
      #
      # When projects is already an association on Person you can use
      # +accepts_nested_attributes_for+ to define the writer method for you:
      #
      #   class Person < ActiveRecord::Base
      #     has_many :projects
      #     accepts_nested_attributes_for :projects
      #   end
      #
      # This model can now be used with a nested fields_for. The block given to
      # the nested fields_for call will be repeated for each instance in the
      # collection:
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       <% if project_fields.object.active? %>
      #         Name: <%= project_fields.text_field :name %>
      #       <% end %>
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # It's also possible to specify the instance to be used:
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <% @person.projects.each do |project| %>
      #       <% if project.active? %>
      #         <%= person_form.fields_for :projects, project do |project_fields| %>
      #           Name: <%= project_fields.text_field :name %>
      #         <% end %>
      #       <% end %>
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # Or a collection to be used:
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects, @active_projects do |project_fields| %>
      #       Name: <%= project_fields.text_field :name %>
      #     <% end %>
      #     ...
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
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Delete: <%= project_fields.check_box :_destroy %>
      #     <% end %>
      #     ...
      #   <% end %>
      def fields_for(record_name, record_object = nil, options = {}, &block)
        builder = instantiate_builder(record_name, record_object, options, &block)
        output = capture(builder, &block)
        output.concat builder.hidden_field(:id) if output && options[:hidden_field_id] && !builder.emitted_hidden_id?
        output
      end

      # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). The text of label will default to the attribute name unless a translation
      # is found in the current I18n locale (through helpers.label.<modelname>.<attribute>) or you specify it explicitly.
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
      #   helpers:
      #     label:
      #       post:
      #         body: "Write your entire text here"
      #
      #   Which then will result in
      #
      #   label(:post, :body)
      #   # => <label for="post_body">Write your entire text here</label>
      #
      # Localization can also be based purely on the translation of the attribute-name
      # (if you are using ActiveRecord):
      #
      #   activerecord:
      #     attributes:
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
      #   label(:post, :terms) do
      #     'Accept <a href="/terms">Terms</a>.'.html_safe
      #   end
      def label(object_name, method, content_or_options = nil, options = nil, &block)
        options ||= {}

        content_is_options = content_or_options.is_a?(Hash)
        if content_is_options || block_given?
          options.merge!(content_or_options) if content_is_options
          text = nil
        else
          text = content_or_options
        end

        InstanceTag.new(object_name, method, self, options.delete(:object)).to_label_tag(text, options, &block)
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
      #   # => <input type="password" id="login_pass" name="login[pass]" size="20" />
      #
      #   password_field(:account, :secret, :class => "form_input", :value => @account.secret)
      #   # => <input type="password" id="account_secret" name="account[secret]" value="#{@account.secret}" class="form_input" />
      #
      #   password_field(:user, :password, :onchange => "if $('user[password]').length > 30 { alert('Your password needs to be shorter!'); }")
      #   # => <input type="password" id="user_password" name="user[password]" onchange = "if $('user[password]').length > 30 { alert('Your password needs to be shorter!'); }"/>
      #
      #   password_field(:account, :pin, :size => 20, :class => 'form_input')
      #   # => <input type="password" id="account_pin" name="account[pin]" size="20" class="form_input" />
      #
      def password_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("password", { :value => nil }.merge!(options))
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

      # Returns a file upload input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # Using this method inside a +form_for+ block will set the enclosing form's encoding to <tt>multipart/form-data</tt>.
      #
      # ==== Examples
      #   file_field(:user, :avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   file_field(:post, :attached, :accept => 'text/html')
      #   # => <input accept="text/html" type="file" id="post_attached" name="post[attached]" />
      #
      #   file_field(:attachment, :file, :class => 'file_input')
      #   # => <input type="file" id="attachment_file" name="attachment[file]" class="file_input" />
      #
      def file_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("file", options.update({:size => nil}))
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
      # if an +Invoice+ model has a +paid+ flag, and in the form that edits a paid
      # invoice the user unchecks its check box, no +paid+ parameter is sent. So,
      # any mass-assignment idiom like
      #
      #   @invoice.update_attributes(params[:invoice])
      #
      # wouldn't update the flag.
      #
      # To prevent this the helper generates an auxiliary hidden field before
      # the very check box. The hidden field has the same name and its
      # attributes mimic an unchecked check box.
      #
      # This way, the client either sends only the hidden field (representing
      # the check box is unchecked), or both fields. Since the HTML specification
      # says key/value pairs have to be sent in the same order they appear in the
      # form, and parameters extraction gets the last occurrence of any repeated
      # key in the query string, that works for ordinary forms.
      #
      # Unfortunately that workaround does not work when the check box goes
      # within an array-like parameter, as in
      #
      #   <%= fields_for "project[invoice_attributes][]", invoice, :index => nil do |form| %>
      #     <%= form.check_box :paid %>
      #     ...
      #   <% end %>
      #
      # because parameter name repetition is precisely what Rails seeks to distinguish
      # the elements of the array. For each item with a checked check box you
      # get an extra ghost item with only that attribute, assigned to "0".
      #
      # In that case it is preferable to either use +check_box_tag+ or to use
      # hashes instead of arrays.
      #
      # ==== Examples
      #   # Let's say that @post.validated? is 1:
      #   check_box("post", "validated")
      #   # => <input name="post[validated]" type="hidden" value="0" />
      #   #    <input type="checkbox" id="post_validated" name="post[validated]" value="1" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #   # => <input name="puppy[gooddog]" type="hidden" value="no" />
      #   #    <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #
      #   check_box("eula", "accepted", { :class => 'eula_check' }, "yes", "no")
      #   # => <input name="eula[accepted]" type="hidden" value="no" />
      #   #    <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
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

      # Returns an input of type "search" for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object_name+). Inputs of type "search" may be styled differently by
      # some browsers.
      #
      # ==== Examples
      #
      #   search_field(:user, :name)
      #   # => <input id="user_name" name="user[name]" size="30" type="search" />
      #   search_field(:user, :name, :autosave => false)
      #   # => <input autosave="false" id="user_name" name="user[name]" size="30" type="search" />
      #   search_field(:user, :name, :results => 3)
      #   # => <input id="user_name" name="user[name]" results="3" size="30" type="search" />
      #   #  Assume request.host returns "www.example.com"
      #   search_field(:user, :name, :autosave => true)
      #   # => <input autosave="com.example.www" id="user_name" name="user[name]" results="10" size="30" type="search" />
      #   search_field(:user, :name, :onsearch => true)
      #   # => <input id="user_name" incremental="true" name="user[name]" onsearch="true" size="30" type="search" />
      #   search_field(:user, :name, :autosave => false, :onsearch => true)
      #   # => <input autosave="false" id="user_name" incremental="true" name="user[name]" onsearch="true" size="30" type="search" />
      #   search_field(:user, :name, :autosave => true, :onsearch => true)
      #   # => <input autosave="com.example.www" id="user_name" incremental="true" name="user[name]" onsearch="true" results="10" size="30" type="search" />
      #
      def search_field(object_name, method, options = {})
        options = options.stringify_keys

        if options["autosave"]
          if options["autosave"] == true
            options["autosave"] = request.host.split(".").reverse.join(".")
          end
          options["results"] ||= 10
        end

        if options["onsearch"]
          options["incremental"] = true unless options.has_key?("incremental")
        end

        InstanceTag.new(object_name, method, self, options.delete("object")).to_input_field_tag("search", options)
      end

      # Returns a text_field of type "tel".
      #
      #   telephone_field("user", "phone")
      #   # => <input id="user_phone" name="user[phone]" size="30" type="tel" />
      #
      def telephone_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("tel", options)
      end
      alias phone_field telephone_field

      # Returns a text_field of type "url".
      #
      #   url_field("user", "homepage")
      #   # => <input id="user_homepage" size="30" name="user[homepage]" type="url" />
      #
      def url_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("url", options)
      end

      # Returns a text_field of type "email".
      #
      #   email_field("user", "address")
      #   # => <input id="user_address" size="30" name="user[address]" type="email" />
      #
      def email_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_input_field_tag("email", options)
      end

      # Returns an input tag of type "number".
      #
      # ==== Options
      # * Accepts same options as number_field_tag
      def number_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_number_field_tag("number", options)
      end

      # Returns an input tag of type "range".
      #
      # ==== Options
      # * Accepts same options as range_field_tag
      def range_field(object_name, method, options = {})
        InstanceTag.new(object_name, method, self, options.delete(:object)).to_number_field_tag("range", options)
      end

      private

        def instantiate_builder(record_name, record_object, options, &block)
          case record_name
          when String, Symbol
            object = record_object
            object_name = record_name
          else
            object = record_name
            object_name = ActiveModel::Naming.param_key(object)
          end

          builder = options[:builder] || default_form_builder
          builder.new(object_name, object, self, options, block)
        end

        def default_form_builder
          builder = ActionView::Base.default_form_builder
          builder.respond_to?(:constantize) ? builder.constantize : builder
        end
    end

    class InstanceTag
      include Helpers::ActiveModelInstanceTag, Helpers::TagHelper, Helpers::FormTagHelper

      attr_reader :object, :method_name, :object_name

      DEFAULT_FIELD_OPTIONS     = { "size" => 30 }
      DEFAULT_RADIO_OPTIONS     = { }
      DEFAULT_TEXT_AREA_OPTIONS = { "cols" => 40, "rows" => 20 }

      def initialize(object_name, method_name, template_object, object = nil)
        @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
        @template_object = template_object

        @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
        @object = retrieve_object(object)
        @auto_index = retrieve_autoindex(Regexp.last_match.pre_match) if Regexp.last_match
      end

      def to_label_tag(text = nil, options = {}, &block)
        options = options.stringify_keys
        tag_value = options.delete("value")
        name_and_id = options.dup

        if name_and_id["for"]
          name_and_id["id"] = name_and_id["for"]
        else
          name_and_id.delete("id")
        end

        add_default_name_and_id_for_value(tag_value, name_and_id)
        options.delete("index")
        options.delete("namespace")
        options["for"] ||= name_and_id["id"]

        if block_given?
          @template_object.label_tag(name_and_id["id"], options, &block)
        else
          content = if text.blank?
            object_name.gsub!(/\[(.*)_attributes\]\[\d\]/, '.\1')
            method_and_value = tag_value.present? ? "#{method_name}.#{tag_value}" : method_name

            if object.respond_to?(:to_model)
              key = object.class.model_name.i18n_key
              i18n_default = ["#{key}.#{method_and_value}".to_sym, ""]
            end

            i18n_default ||= ""
            I18n.t("#{object_name}.#{method_and_value}", :default => i18n_default, :scope => "helpers.label").presence
          else
            text.to_s
          end

          content ||= if object && object.class.respond_to?(:human_attribute_name)
            object.class.human_attribute_name(method_name)
          end

          content ||= method_name.humanize

          label_tag(name_and_id["id"], content, options)
        end
      end

      def to_input_field_tag(field_type, options = {})
        options = options.stringify_keys
        options["size"] = options["maxlength"] || DEFAULT_FIELD_OPTIONS["size"] unless options.key?("size")
        options = DEFAULT_FIELD_OPTIONS.merge(options)
        if field_type == "hidden"
          options.delete("size")
        end
        options["type"]  ||= field_type
        options["value"] = options.fetch("value"){ value_before_type_cast(object) } unless field_type == "file"
        options["value"] &&= ERB::Util.html_escape(options["value"])
        add_default_name_and_id(options)
        tag("input", options)
      end

      def to_number_field_tag(field_type, options = {})
        options = options.stringify_keys
        options['size'] ||= nil

        if range = options.delete("in") || options.delete("within")
          options.update("min" => range.min, "max" => range.max)
        end
        to_input_field_tag(field_type, options)
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

        content_tag("textarea", options.delete('value') || value_before_type_cast(object), options)
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
        if options["multiple"]
          add_default_name_and_id_for_value(checked_value, options)
          options.delete("multiple")
        else
          add_default_name_and_id(options)
        end
        hidden = unchecked_value ? tag("input", "name" => options["name"], "type" => "hidden", "value" => unchecked_value, "disabled" => options["disabled"]) : ""
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

      def retrieve_object(object)
        if object
          object
        elsif @template_object.instance_variable_defined?("@#{@object_name}")
          @template_object.instance_variable_get("@#{@object_name}")
        end
      rescue NameError
        # As @object_name may contain the nested syntax (item[subobject]) we need to fallback to nil.
        nil
      end

      def retrieve_autoindex(pre_match)
        object = self.object || @template_object.instance_variable_get("@#{pre_match}")
        if object && object.respond_to?(:to_param)
          object.to_param
        else
          raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
        end
      end

      def value(object)
        self.class.value(object, @method_name)
      end

      def value_before_type_cast(object)
        self.class.value_before_type_cast(object, @method_name)
      end

      class << self
        def value(object, method_name)
          object.send method_name if object
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
            pretty_tag_value = tag_value.to_s.gsub(/\s/, "_").gsub(/[^-\w]/, "").downcase
            specified_id = options["id"]
            add_default_name_and_id(options)
            options["id"] += "_#{pretty_tag_value}" if specified_id.blank? && options["id"].present?
          else
            add_default_name_and_id(options)
          end
        end

        def add_default_name_and_id(options)
          if options.has_key?("index")
            options["name"] ||= tag_name_with_index(options["index"], options["multiple"])
            options["id"] = options.fetch("id"){ tag_id_with_index(options["index"]) }
            options.delete("index")
          elsif defined?(@auto_index)
            options["name"] ||= tag_name_with_index(@auto_index, options["multiple"])
            options["id"] = options.fetch("id"){ tag_id_with_index(@auto_index) }
          else
            options["name"] ||= tag_name(options["multiple"])
            options["id"] = options.fetch("id"){ tag_id }
          end

          options["id"] = [options.delete('namespace'), options["id"]].compact.join("_").presence
        end

        def tag_name(multiple = false)
          "#{@object_name}[#{sanitized_method_name}]#{"[]" if multiple}"
        end

        def tag_name_with_index(index, multiple = false)
          "#{@object_name}[#{index}][#{sanitized_method_name}]#{"[]" if multiple}"
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

    class FormBuilder
      # The methods which wrap a form helper call.
      class_attribute :field_helpers
      self.field_helpers = FormHelper.instance_method_names - %w(form_for convert_to_model)

      attr_accessor :object_name, :object, :options

      attr_reader :multipart, :parent_builder
      alias :multipart? :multipart

      def multipart=(multipart)
        @multipart = multipart
        parent_builder.multipart = multipart if parent_builder
      end

      def self._to_partial_path
        @_to_partial_path ||= name.demodulize.underscore.sub!(/_builder$/, '')
      end

      def to_partial_path
        self.class._to_partial_path
      end

      def to_model
        self
      end

      def initialize(object_name, object, template, options, proc)
        @nested_child_index = {}
        @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc
        @parent_builder = options[:parent_builder]
        @default_options = @options ? @options.slice(:index, :namespace) : {}
        if @object_name.to_s.match(/\[\]$/)
          if object ||= @template.instance_variable_get("@#{Regexp.last_match.pre_match}") and object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end
        @multipart = nil
      end

      (field_helpers - %w(label check_box radio_button fields_for hidden_field file_field)).each do |selector|
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def #{selector}(method, options = {})  # def text_field(method, options = {})
            @template.send(                      #   @template.send(
              #{selector.inspect},               #     "text_field",
              @object_name,                      #     @object_name,
              method,                            #     method,
              objectify_options(options))        #     objectify_options(options))
          end                                    # end
        RUBY_EVAL
      end

      def fields_for(record_name, record_object = nil, fields_options = {}, &block)
        fields_options, record_object = record_object, nil if record_object.is_a?(Hash) && record_object.extractable_options?
        fields_options[:builder] ||= options[:builder]
        fields_options[:parent_builder] = self
        fields_options[:namespace] = fields_options[:parent_builder].options[:namespace]

        case record_name
        when String, Symbol
          if nested_attributes_association?(record_name)
            return fields_for_with_nested_attributes(record_name, record_object, fields_options, block)
          end
        else
          record_object = record_name.is_a?(Array) ? record_name.last : record_name
          record_name   = ActiveModel::Naming.param_key(record_object)
        end

        index = if options.has_key?(:index)
          "[#{options[:index]}]"
        elsif defined?(@auto_index)
          self.object_name = @object_name.to_s.sub(/\[\]$/,"")
          "[#{@auto_index}]"
        end
        record_name = "#{object_name}#{index}[#{record_name}]"

        @template.fields_for(record_name, record_object, fields_options, &block)
      end

      def label(method, text = nil, options = {}, &block)
        @template.label(@object_name, method, text, objectify_options(options), &block)
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

      def file_field(method, options = {})
        self.multipart = true
        @template.file_field(@object_name, method, objectify_options(options))
      end

      # Add the submit button for the given form. When no value is given, it checks
      # if the object is a new resource or not to create the proper label:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # In the example above, if @post is a new record, it will use "Create Post" as
      # submit button label, otherwise, it uses "Update Post".
      #
      # Those labels can be customized using I18n, under the helpers.submit key and accept
      # the %{model} as translation interpolation:
      #
      #   en:
      #     helpers:
      #       submit:
      #         create: "Create a %{model}"
      #         update: "Confirm changes to %{model}"
      #
      # It also searches for a key specific for the given object:
      #
      #   en:
      #     helpers:
      #       submit:
      #         post:
      #           create: "Add %{model}"
      #
      def submit(value=nil, options={})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.submit_tag(value, options)
      end

      # Add the submit button for the given form. When no value is given, it checks
      # if the object is a new resource or not to create the proper label:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.button %>
      #   <% end %>
      #
      # In the example above, if @post is a new record, it will use "Create Post" as
      # submit button label, otherwise, it uses "Update Post".
      #
      # Those labels can be customized using I18n, under the helpers.submit key and accept
      # the %{model} as translation interpolation:
      #
      #   en:
      #     helpers:
      #       button:
      #         create: "Create a %{model}"
      #         update: "Confirm changes to %{model}"
      #
      # It also searches for a key specific for the given object:
      #
      #   en:
      #     helpers:
      #       button:
      #         post:
      #           create: "Add %{model}"
      #
      def button(value=nil, options={})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.button_tag(value, options)
      end

      def emitted_hidden_id?
        @emitted_hidden_id ||= nil
      end

      private
        def objectify_options(options)
          @default_options.merge(options.merge(:object => @object))
        end

        def submit_default_value
          object = convert_to_model(@object)
          key    = object ? (object.persisted? ? :update : :create) : :submit

          model = if object.class.respond_to?(:model_name)
            object.class.model_name.human
          else
            @object_name.to_s.humanize
          end

          defaults = []
          defaults << :"helpers.submit.#{object_name}.#{key}"
          defaults << :"helpers.submit.#{key}"
          defaults << "#{key.to_s.humanize} #{model}"

          I18n.t(defaults.shift, :model => model, :default => defaults)
        end

        def nested_attributes_association?(association_name)
          @object.respond_to?("#{association_name}_attributes=")
        end

        def fields_for_with_nested_attributes(association_name, association, options, block)
          name = "#{object_name}[#{association_name}_attributes]"
          association = convert_to_model(association)

          if association.respond_to?(:persisted?)
            association = [association] if @object.send(association_name).is_a?(Array)
          elsif !association.respond_to?(:to_ary)
            association = @object.send(association_name)
          end

          if association.respond_to?(:to_ary)
            explicit_child_index = options[:child_index]
            output = ActiveSupport::SafeBuffer.new
            association.each do |child|
              output << fields_for_nested_model("#{name}[#{explicit_child_index || nested_child_index(name)}]", child, options, block)
            end
            output
          elsif association
            fields_for_nested_model(name, association, options, block)
          end
        end

        def fields_for_nested_model(name, object, options, block)
          object = convert_to_model(object)

          parent_include_id = self.options.fetch(:include_id, true)
          include_id = options.fetch(:include_id, parent_include_id)
          options[:hidden_field_id] = object.persisted? && include_id
          @template.fields_for(name, object, options, &block)
        end

        def nested_child_index(name)
          @nested_child_index[name] ||= -1
          @nested_child_index[name] += 1
        end

        def convert_to_model(object)
          object.respond_to?(:to_model) ? object.to_model : object
        end
    end
  end

  ActiveSupport.on_load(:action_view) do
    class ActionView::Base
      cattr_accessor :default_form_builder
      @@default_form_builder = ::ActionView::Helpers::FormBuilder
    end
  end
end

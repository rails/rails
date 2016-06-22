require 'cgi'
require 'action_view/helpers/date_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_tag_helper'
require 'action_view/helpers/active_model_helper'
require 'action_view/model_naming'
require 'action_view/record_identifier'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/string/output_safety'
require 'active_support/core_ext/string/inflections'

module ActionView
  # = Action View Form Helpers
  module Helpers
    # Form helpers are designed to make working with resources much easier
    # compared to using vanilla HTML.
    #
    # Typically, a form designed to create or update a resource reflects the
    # identity of the resource in several ways: (i) the url that the form is
    # sent to (the form element's +action+ attribute) should result in a request
    # being routed to the appropriate controller action (with the appropriate <tt>:id</tt>
    # parameter in the case of an existing resource), (ii) input fields should
    # be named in such a way that in the controller their values appear in the
    # appropriate places within the +params+ hash, and (iii) for an existing record,
    # when the form is initially displayed, input fields corresponding to attributes
    # of the resource should show the current values of those attributes.
    #
    # In Rails, this is usually achieved by creating the form using +form_for+ and
    # a number of related helper methods. +form_for+ generates an appropriate <tt>form</tt>
    # tag and yields a form builder object that knows the model the form is about.
    # Input fields are created by calling methods defined on the form builder, which
    # means they are able to generate the appropriate names and default values
    # corresponding to the model attributes, as well as convenient IDs, etc.
    # Conventions in the generated field names allow controllers to receive form data
    # nicely structured in +params+ with no effort on your side.
    #
    # For example, to create a new person you typically set up a new instance of
    # +Person+ in the <tt>PeopleController#new</tt> action, <tt>@person</tt>, and
    # in the view template pass that object to +form_for+:
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
    #     <input name="authenticity_token" type="hidden" value="NrOp5bsjoLRuK8IW5+dQEYjKGUJDe7TQoZVvq95Wteg=" />
    #     <label for="person_first_name">First name</label>:
    #     <input id="person_first_name" name="person[first_name]" type="text" /><br />
    #
    #     <label for="person_last_name">Last name</label>:
    #     <input id="person_last_name" name="person[last_name]" type="text" /><br />
    #
    #     <input name="commit" type="submit" value="Create Person" />
    #   </form>
    #
    # As you see, the HTML reflects knowledge about the resource in several spots,
    # like the path the form should be submitted to, or the names of the input fields.
    #
    # In particular, thanks to the conventions followed in the generated field names, the
    # controller gets a nested hash <tt>params[:person]</tt> with the person attributes
    # set in the form. That hash is ready to be passed to <tt>Person.new</tt>:
    #
    #   @person = Person.new(params[:person])
    #   if @person.save
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
    #     <input name="_method" type="hidden" value="patch" />
    #     <input name="authenticity_token" type="hidden" value="NrOp5bsjoLRuK8IW5+dQEYjKGUJDe7TQoZVvq95Wteg=" />
    #     <label for="person_first_name">First name</label>:
    #     <input id="person_first_name" name="person[first_name]" type="text" value="John" /><br />
    #
    #     <label for="person_last_name">Last name</label>:
    #     <input id="person_last_name" name="person[last_name]" type="text" value="Smith" /><br />
    #
    #     <input name="commit" type="submit" value="Update Person" />
    #   </form>
    #
    # Note that the endpoint, default values, and submit button label are tailored for <tt>@person</tt>.
    # That works that way because the involved helpers know whether the resource is a new record or not,
    # and generate HTML accordingly.
    #
    # The controller would receive the form data again in <tt>params[:person]</tt>, ready to be
    # passed to <tt>Person#update</tt>:
    #
    #   if @person.update(params[:person])
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
      include ModelNaming
      include RecordIdentifier

      attr_internal :default_form_builder

      # Creates a form that allows the user to create or update the attributes
      # of a specific model object.
      #
      # The method can be used in several slightly different ways, depending on
      # how much you wish to rely on Rails to infer automatically from the model
      # how the form should be constructed. For a generic model object, a form
      # can be created by passing +form_for+ a string or symbol representing
      # the object we are concerned with:
      #
      #   <%= form_for :person do |f| %>
      #     First name: <%= f.text_field :first_name %><br />
      #     Last name : <%= f.text_field :last_name %><br />
      #     Biography : <%= f.text_area :biography %><br />
      #     Admin?    : <%= f.check_box :admin %><br />
      #     <%= f.submit %>
      #   <% end %>
      #
      # The variable +f+ yielded to the block is a FormBuilder object that
      # incorporates the knowledge about the model object represented by
      # <tt>:person</tt> passed to +form_for+. Methods defined on the FormBuilder
      # are used to generate fields bound to this model. Thus, for example,
      #
      #   <%= f.text_field :first_name %>
      #
      # will get expanded to
      #
      #   <%= text_field :person, :first_name %>
      #
      # which results in an HTML <tt><input></tt> tag whose +name+ attribute is
      # <tt>person[first_name]</tt>. This means that when the form is submitted,
      # the value entered by the user will be available in the controller as
      # <tt>params[:person][:first_name]</tt>.
      #
      # For fields generated in this way using the FormBuilder,
      # if <tt>:person</tt> also happens to be the name of an instance variable
      # <tt>@person</tt>, the default value of the field shown when the form is
      # initially displayed (e.g. in the situation where you are editing an
      # existing record) will be the value of the corresponding attribute of
      # <tt>@person</tt>.
      #
      # The rightmost argument to +form_for+ is an
      # optional hash of options -
      #
      # * <tt>:url</tt> - The URL the form is to be submitted to. This may be
      #   represented in the same way as values passed to +url_for+ or +link_to+.
      #   So for example you may use a named route directly. When the model is
      #   represented by a string or symbol, as in the example above, if the
      #   <tt>:url</tt> option is not specified, by default the form will be
      #   sent back to the current url (We will describe below an alternative
      #   resource-oriented usage of +form_for+ in which the URL does not need
      #   to be specified explicitly).
      # * <tt>:namespace</tt> - A namespace for your form to ensure uniqueness of
      #   id attributes on form elements. The namespace attribute will be prefixed
      #   with underscore on the generated HTML id.
      # * <tt>:method</tt> - The method to use when submitting the form, usually
      #   either "get" or "post". If "patch", "put", "delete", or another verb
      #   is used, a hidden input with name <tt>_method</tt> is added to
      #   simulate the verb over post.
      # * <tt>:authenticity_token</tt> - Authenticity token to use in the form.
      #   Use only if you need to pass custom authenticity token string, or to
      #   not add authenticity_token field at all (by passing <tt>false</tt>).
      #   Remote forms may omit the embedded authenticity token by setting
      #   <tt>config.action_view.embed_authenticity_token_in_remote_forms = false</tt>.
      #   This is helpful when you're fragment-caching the form. Remote forms
      #   get the authenticity token from the <tt>meta</tt> tag, so embedding is
      #   unnecessary unless you support browsers without JavaScript.
      # * <tt>:remote</tt> - If set to true, will allow the Unobtrusive
      #   JavaScript drivers to control the submit behavior. By default this
      #   behavior is an ajax submit.
      # * <tt>:enforce_utf8</tt> - If set to false, a hidden input with name
      #   utf8 is not output.
      # * <tt>:html</tt> - Optional HTML attributes for the form tag.
      #
      # Also note that +form_for+ doesn't create an exclusive scope. It's still
      # possible to use both the stand-alone FormHelper methods and methods
      # from FormTagHelper. For example:
      #
      #   <%= form_for :person do |f| %>
      #     First name: <%= f.text_field :first_name %>
      #     Last name : <%= f.text_field :last_name %>
      #     Biography : <%= text_area :person, :biography %>
      #     Admin?    : <%= check_box_tag "person[admin]", "1", @person.company.admin? %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # This also works for the methods in FormOptionHelper and DateHelper that
      # are designed to work with an object as base, like
      # FormOptionHelper#collection_select and DateHelper#datetime_select.
      #
      # === #form_for with a model object
      #
      # In the examples above, the object to be created or edited was
      # represented by a symbol passed to +form_for+, and we noted that
      # a string can also be used equivalently. It is also possible, however,
      # to pass a model object itself to +form_for+. For example, if <tt>@post</tt>
      # is an existing record you wish to edit, you can create the form using
      #
      #   <%= form_for @post do |f| %>
      #     ...
      #   <% end %>
      #
      # This behaves in almost the same way as outlined previously, with a
      # couple of small exceptions. First, the prefix used to name the input
      # elements within the form (hence the key that denotes them in the +params+
      # hash) is actually derived from the object's _class_, e.g. <tt>params[:post]</tt>
      # if the object's class is +Post+. However, this can be overwritten using
      # the <tt>:as</tt> option, e.g. -
      #
      #   <%= form_for(@person, as: :client) do |f| %>
      #     ...
      #   <% end %>
      #
      # would result in <tt>params[:client]</tt>.
      #
      # Secondly, the field values shown when the form is initially displayed
      # are taken from the attributes of the object passed to +form_for+,
      # regardless of whether the object is an instance
      # variable. So, for example, if we had a _local_ variable +post+
      # representing an existing record,
      #
      #   <%= form_for post do |f| %>
      #     ...
      #   <% end %>
      #
      # would produce a form with fields whose initial state reflect the current
      # values of the attributes of +post+.
      #
      # === Resource-oriented style
      #
      # In the examples just shown, although not indicated explicitly, we still
      # need to use the <tt>:url</tt> option in order to specify where the
      # form is going to be sent. However, further simplification is possible
      # if the record passed to +form_for+ is a _resource_, i.e. it corresponds
      # to a set of RESTful routes, e.g. defined using the +resources+ method
      # in <tt>config/routes.rb</tt>. In this case Rails will simply infer the
      # appropriate URL from the record itself. For example,
      #
      #   <%= form_for @post do |f| %>
      #     ...
      #   <% end %>
      #
      # is then equivalent to something like:
      #
      #   <%= form_for @post, as: :post, url: post_path(@post), method: :patch, html: { class: "edit_post", id: "edit_post_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # And for a new record
      #
      #   <%= form_for(Post.new) do |f| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <%= form_for @post, as: :post, url: posts_path, html: { class: "new_post", id: "new_post" } do |f| %>
      #     ...
      #   <% end %>
      #
      # However you can still overwrite individual conventions, such as:
      #
      #   <%= form_for(@post, url: super_posts_path) do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also set the answer format, like this:
      #
      #   <%= form_for(@post, format: :json) do |f| %>
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
      #    method: (:get|:post|:patch|:put|:delete)
      #
      # in the options hash. If the verb is not GET or POST, which are natively
      # supported by HTML forms, the form will be set to POST and a hidden input
      # called _method will carry the intended verb for the server to interpret.
      #
      # === Unobtrusive JavaScript
      #
      # Specifying:
      #
      #    remote: true
      #
      # in the options hash creates a form that will allow the unobtrusive JavaScript drivers to modify its
      # behavior. The expected default behavior is an XMLHttpRequest in the background instead of the regular
      # POST arrangement, but ultimately the behavior is the choice of the JavaScript driver implementor.
      # Even though it's using JavaScript to serialize the form elements, the form submission will work just like
      # a regular submission as viewed by the receiving side (all elements available in <tt>params</tt>).
      #
      # Example:
      #
      #   <%= form_for(@post, remote: true) do |f| %>
      #     ...
      #   <% end %>
      #
      # The HTML generated for this would be:
      #
      #   <form action='http://www.example.com' method='post' data-remote='true'>
      #     <input name='_method' type='hidden' value='patch' />
      #     ...
      #   </form>
      #
      # === Setting HTML options
      #
      # You can set data attributes directly by passing in a data hash, but all other HTML options must be wrapped in
      # the HTML key. Example:
      #
      #   <%= form_for(@post, data: { behavior: "autosave" }, html: { name: "go" }) do |f| %>
      #     ...
      #   <% end %>
      #
      # The HTML generated for this would be:
      #
      #   <form action='http://www.example.com' method='post' data-behavior='autosave' name='go'>
      #     <input name='_method' type='hidden' value='patch' />
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
      #     <%= f.fields_for(:comments, include_id: false) do |cf| %>
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
      #   <%= form_for @person, url: { action: "create" }, builder: LabellingFormBuilder do |f| %>
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
      #     form_for(record_or_name_or_array, *(args << options.merge(builder: LabellingFormBuilder)), &block)
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
      #   <%= form_for @invoice, url: external_url, authenticity_token: 'external_token' do |f|
      #     ...
      #   <% end %>
      #
      # If you don't want to an authenticity token field be rendered at all just pass <tt>false</tt>:
      #
      #   <%= form_for @invoice, url: external_url, authenticity_token: false do |f|
      #     ...
      #   <% end %>
      def form_for(record, options = {}, &block)
        raise ArgumentError, "Missing block" unless block_given?
        html_options = options[:html] ||= {}

        case record
        when String, Symbol
          object_name = record
          object      = nil
        else
          object      = record.is_a?(Array) ? record.last : record
          raise ArgumentError, "First argument in form cannot contain nil or be empty" unless object
          object_name = options[:as] || model_name_from_record_or_class(object).param_key
          apply_form_for_options!(record, object, options)
        end

        html_options[:data]   = options.delete(:data)   if options.has_key?(:data)
        html_options[:remote] = options.delete(:remote) if options.has_key?(:remote)
        html_options[:method] = options.delete(:method) if options.has_key?(:method)
        html_options[:enforce_utf8] = options.delete(:enforce_utf8) if options.has_key?(:enforce_utf8)
        html_options[:authenticity_token] = options.delete(:authenticity_token)

        builder = instantiate_builder(object_name, object, options)
        output  = capture(builder, &block)
        html_options[:multipart] ||= builder.multipart?

        html_options = html_options_for_form(options[:url] || {}, html_options)
        form_tag_with_body(html_options, output)
      end

      def apply_form_for_options!(record, object, options) #:nodoc:
        object = convert_to_model(object)

        as = options[:as]
        namespace = options[:namespace]
        action, method = object.respond_to?(:persisted?) && object.persisted? ? [:edit, :patch] : [:new, :post]
        options[:html].reverse_merge!(
          class:  as ? "#{action}_#{as}" : dom_class(object, action),
          id:     (as ? [namespace, action, as] : [namespace, dom_id(object, action)]).compact.join("_").presence,
          method: method
        )

        options[:url] ||= if options.key?(:format)
                            polymorphic_path(record, format: options.delete(:format))
                          else
                            polymorphic_path(record, {})
                          end
      end
      private :apply_form_for_options!

      # Creates a scope around a specific model object like form_for, but
      # doesn't create the form tags themselves. This makes fields_for suitable
      # for specifying additional model objects in the same form.
      #
      # Although the usage and purpose of +fields_for+ is similar to +form_for+'s,
      # its method signature is slightly different. Like +form_for+, it yields
      # a FormBuilder object associated with a particular model object to a block,
      # and within the block allows methods to be called on the builder to
      # generate fields associated with the model object. Fields may reflect
      # a model object in two ways - how they are named (hence how submitted
      # values appear within the +params+ hash in the controller) and what
      # default values are shown when the form the fields appear in is first
      # displayed. In order for both of these features to be specified independently,
      # both an object name (represented by either a symbol or string) and the
      # object itself can be passed to the method separately -
      #
      #   <%= form_for @person do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <%= fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #
      #     <%= person_form.submit %>
      #   <% end %>
      #
      # In this case, the checkbox field will be represented by an HTML +input+
      # tag with the +name+ attribute <tt>permission[admin]</tt>, and the submitted
      # value will appear in the controller as <tt>params[:permission][:admin]</tt>.
      # If <tt>@person.permission</tt> is an existing record with an attribute
      # +admin+, the initial state of the checkbox when first displayed will
      # reflect the value of <tt>@person.permission.admin</tt>.
      #
      # Often this can be simplified by passing just the name of the model
      # object to +fields_for+ -
      #
      #   <%= fields_for :permission do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # ...in which case, if <tt>:permission</tt> also happens to be the name of an
      # instance variable <tt>@permission</tt>, the initial state of the input
      # field will reflect the value of that variable's attribute <tt>@permission.admin</tt>.
      #
      # Alternatively, you can pass just the model object itself (if the first
      # argument isn't a string or symbol +fields_for+ will realize that the
      # name has been omitted) -
      #
      #   <%= fields_for @person.permission do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # and +fields_for+ will derive the required name of the field from the
      # _class_ of the model object, e.g. if <tt>@person.permission</tt>, is
      # of class +Permission+, the field will still be named <tt>permission[admin]</tt>.
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
      #     accepts_nested_attributes_for :address, allow_destroy: true
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
      # If you want to destroy any of the associated models through the
      # form, you have to enable it first using the <tt>:allow_destroy</tt>
      # option for +accepts_nested_attributes_for+:
      #
      #   class Person < ActiveRecord::Base
      #     has_many :projects
      #     accepts_nested_attributes_for :projects, allow_destroy: true
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
      #
      # When a collection is used you might want to know the index of each
      # object into the array. For this purpose, the <tt>index</tt> method
      # is available in the FormBuilder object.
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Project #<%= project_fields.index %>
      #       ...
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # Note that fields_for will automatically generate a hidden field
      # to store the ID of the record. There are circumstances where this
      # hidden field is not needed and you can pass <tt>include_id: false</tt>
      # to prevent fields_for from rendering it automatically.
      def fields_for(record_name, record_object = nil, options = {}, &block)
        builder = instantiate_builder(record_name, record_object, options)
        capture(builder, &block)
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
      # You can localize your labels based on model and attribute names.
      # For example you can define the following in your locale (e.g. en.yml)
      #
      #   helpers:
      #     label:
      #       post:
      #         body: "Write your entire text here"
      #
      # Which then will result in
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
      #   label(:post, :title, "A short title", class: "title_label")
      #   # => <label for="post_title" class="title_label">A short title</label>
      #
      #   label(:post, :privacy, "Public Post", value: "public")
      #   # => <label for="post_privacy_public">Public Post</label>
      #
      #   label(:post, :terms) do
      #     raw('Accept <a href="/terms">Terms</a>.')
      #   end
      #   # => <label for="post_terms">Accept <a href="/terms">Terms</a>.</label>
      def label(object_name, method, content_or_options = nil, options = nil, &block)
        Tags::Label.new(object_name, method, self, content_or_options, options).render(&block)
      end

      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   text_field(:post, :title, size: 20)
      #   # => <input type="text" id="post_title" name="post[title]" size="20" value="#{@post.title}" />
      #
      #   text_field(:post, :title, class: "create_input")
      #   # => <input type="text" id="post_title" name="post[title]" value="#{@post.title}" class="create_input" />
      #
      #   text_field(:session, :user, onchange: "if ($('#session_user').val() === 'admin') { alert('Your login cannot be admin!'); }")
      #   # => <input type="text" id="session_user" name="session[user]" value="#{@session.user}" onchange="if ($('#session_user').val() === 'admin') { alert('Your login cannot be admin!'); }"/>
      #
      #   text_field(:snippet, :code, size: 20, class: 'code_input')
      #   # => <input type="text" id="snippet_code" name="snippet[code]" size="20" value="#{@snippet.code}" class="code_input" />
      def text_field(object_name, method, options = {})
        Tags::TextField.new(object_name, method, self, options).render
      end

      # Returns an input tag of the "password" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown. For security reasons this field is blank by default; pass in a value via +options+ if this is not desired.
      #
      # ==== Examples
      #   password_field(:login, :pass, size: 20)
      #   # => <input type="password" id="login_pass" name="login[pass]" size="20" />
      #
      #   password_field(:account, :secret, class: "form_input", value: @account.secret)
      #   # => <input type="password" id="account_secret" name="account[secret]" value="#{@account.secret}" class="form_input" />
      #
      #   password_field(:user, :password, onchange: "if ($('#user_password').val().length > 30) { alert('Your password needs to be shorter!'); }")
      #   # => <input type="password" id="user_password" name="user[password]" onchange="if ($('#user_password').val().length > 30) { alert('Your password needs to be shorter!'); }"/>
      #
      #   password_field(:account, :pin, size: 20, class: 'form_input')
      #   # => <input type="password" id="account_pin" name="account[pin]" size="20" class="form_input" />
      def password_field(object_name, method, options = {})
        Tags::PasswordField.new(object_name, method, self, options).render
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
        Tags::HiddenField.new(object_name, method, self, options).render
      end

      # Returns a file upload input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # Using this method inside a +form_for+ block will set the enclosing form's encoding to <tt>multipart/form-data</tt>.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:multiple</tt> - If set to true, *in most updated browsers* the user will be allowed to select multiple files.
      # * <tt>:accept</tt> - If set to one or multiple mime-types, the user will be suggested a filter when choosing a file. You still need to set up model validations.
      #
      # ==== Examples
      #   file_field(:user, :avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   file_field(:post, :image, multiple: true)
      #   # => <input type="file" id="post_image" name="post[image][]" multiple="multiple" />
      #
      #   file_field(:post, :attached, accept: 'text/html')
      #   # => <input accept="text/html" type="file" id="post_attached" name="post[attached]" />
      #
      #   file_field(:post, :image, accept: 'image/png,image/gif,image/jpeg')
      #   # => <input type="file" id="post_image" name="post[image]" accept="image/png,image/gif,image/jpeg" />
      #
      #   file_field(:attachment, :file, class: 'file_input')
      #   # => <input type="file" id="attachment_file" name="attachment[file]" class="file_input" />
      def file_field(object_name, method, options = {})
        Tags::FileField.new(object_name, method, self, options).render
      end

      # Returns a textarea opening and closing tag set tailored for accessing a specified attribute (identified by +method+)
      # on an object assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # ==== Examples
      #   text_area(:post, :body, cols: 20, rows: 40)
      #   # => <textarea cols="20" rows="40" id="post_body" name="post[body]">
      #   #      #{@post.body}
      #   #    </textarea>
      #
      #   text_area(:comment, :text, size: "20x30")
      #   # => <textarea cols="20" rows="30" id="comment_text" name="comment[text]">
      #   #      #{@comment.text}
      #   #    </textarea>
      #
      #   text_area(:application, :notes, cols: 40, rows: 15, class: 'app_input')
      #   # => <textarea cols="40" rows="15" id="application_notes" name="application[notes]" class="app_input">
      #   #      #{@application.notes}
      #   #    </textarea>
      #
      #   text_area(:entry, :body, size: "20x20", disabled: 'disabled')
      #   # => <textarea cols="20" rows="20" id="entry_body" name="entry[body]" disabled="disabled">
      #   #      #{@entry.body}
      #   #    </textarea>
      def text_area(object_name, method, options = {})
        Tags::TextArea.new(object_name, method, self, options).render
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
      #   @invoice.update(params[:invoice])
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
      #   <%= fields_for "project[invoice_attributes][]", invoice, index: nil do |form| %>
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
      #   # Let's say that @post.validated? is 1:
      #   check_box("post", "validated")
      #   # => <input name="post[validated]" type="hidden" value="0" />
      #   #    <input checked="checked" type="checkbox" id="post_validated" name="post[validated]" value="1" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   check_box("puppy", "gooddog", {}, "yes", "no")
      #   # => <input name="puppy[gooddog]" type="hidden" value="no" />
      #   #    <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #
      #   check_box("eula", "accepted", { class: 'eula_check' }, "yes", "no")
      #   # => <input name="eula[accepted]" type="hidden" value="no" />
      #   #    <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
      def check_box(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        Tags::CheckBox.new(object_name, method, self, checked_value, unchecked_value, options).render
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked.
      #
      # To force the radio button to be checked pass <tt>checked: true</tt> in the
      # +options+ hash. You may pass HTML options there as well.
      #
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
        Tags::RadioButton.new(object_name, method, self, tag_value, options).render
      end

      # Returns a text_field of type "color".
      #
      #   color_field("car", "color")
      #   # => <input id="car_color" name="car[color]" type="color" value="#000000" />
      def color_field(object_name, method, options = {})
        Tags::ColorField.new(object_name, method, self, options).render
      end

      # Returns an input of type "search" for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object_name+). Inputs of type "search" may be styled differently by
      # some browsers.
      #
      #   search_field(:user, :name)
      #   # => <input id="user_name" name="user[name]" type="search" />
      #   search_field(:user, :name, autosave: false)
      #   # => <input autosave="false" id="user_name" name="user[name]" type="search" />
      #   search_field(:user, :name, results: 3)
      #   # => <input id="user_name" name="user[name]" results="3" type="search" />
      #   #  Assume request.host returns "www.example.com"
      #   search_field(:user, :name, autosave: true)
      #   # => <input autosave="com.example.www" id="user_name" name="user[name]" results="10" type="search" />
      #   search_field(:user, :name, onsearch: true)
      #   # => <input id="user_name" incremental="true" name="user[name]" onsearch="true" type="search" />
      #   search_field(:user, :name, autosave: false, onsearch: true)
      #   # => <input autosave="false" id="user_name" incremental="true" name="user[name]" onsearch="true" type="search" />
      #   search_field(:user, :name, autosave: true, onsearch: true)
      #   # => <input autosave="com.example.www" id="user_name" incremental="true" name="user[name]" onsearch="true" results="10" type="search" />
      def search_field(object_name, method, options = {})
        Tags::SearchField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "tel".
      #
      #   telephone_field("user", "phone")
      #   # => <input id="user_phone" name="user[phone]" type="tel" />
      #
      def telephone_field(object_name, method, options = {})
        Tags::TelField.new(object_name, method, self, options).render
      end
      # aliases telephone_field
      alias phone_field telephone_field

      # Returns a text_field of type "date".
      #
      #   date_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="date" />
      #
      # The default value is generated by trying to call +strftime+ with "%Y-%m-%d"
      # on the object's value, which makes it behave as expected for instances
      # of DateTime and ActiveSupport::TimeWithZone. You can still override that
      # by passing the "value" option explicitly, e.g.
      #
      #   @user.born_on = Date.new(1984, 1, 27)
      #   date_field("user", "born_on", value: "1984-05-12")
      #   # => <input id="user_born_on" name="user[born_on]" type="date" value="1984-05-12" />
      #
      # You can create values for the "min" and "max" attributes by passing
      # instances of Date or Time to the options hash.
      #
      #   date_field("user", "born_on", min: Date.today)
      #   # => <input id="user_born_on" name="user[born_on]" type="date" min="2014-05-20" />
      #
      # Alternatively, you can pass a String formatted as an ISO8601 date as the
      # values for "min" and "max."
      #
      #   date_field("user", "born_on", min: "2014-05-20")
      #   # => <input id="user_born_on" name="user[born_on]" type="date" min="2014-05-20" />
      #
      def date_field(object_name, method, options = {})
        Tags::DateField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "time".
      #
      # The default value is generated by trying to call +strftime+ with "%T.%L"
      # on the object's value. It is still possible to override that
      # by passing the "value" option.
      #
      # === Options
      # * Accepts same options as time_field_tag
      #
      # === Example
      #   time_field("task", "started_at")
      #   # => <input id="task_started_at" name="task[started_at]" type="time" />
      #
      # You can create values for the "min" and "max" attributes by passing
      # instances of Date or Time to the options hash.
      #
      #   time_field("task", "started_at", min: Time.now)
      #   # => <input id="task_started_at" name="task[started_at]" type="time" min="01:00:00.000" />
      #
      # Alternatively, you can pass a String formatted as an ISO8601 time as the
      # values for "min" and "max."
      #
      #   time_field("task", "started_at", min: "01:00:00")
      #   # => <input id="task_started_at" name="task[started_at]" type="time" min="01:00:00.000" />
      #
      def time_field(object_name, method, options = {})
        Tags::TimeField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "datetime-local".
      #
      #   datetime_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="datetime-local" />
      #
      # The default value is generated by trying to call +strftime+ with "%Y-%m-%dT%T"
      # on the object's value, which makes it behave as expected for instances
      # of DateTime and ActiveSupport::TimeWithZone.
      #
      #   @user.born_on = Date.new(1984, 1, 12)
      #   datetime_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="datetime-local" value="1984-01-12T00:00:00" />
      #
      # You can create values for the "min" and "max" attributes by passing
      # instances of Date or Time to the options hash.
      #
      #   datetime_field("user", "born_on", min: Date.today)
      #   # => <input id="user_born_on" name="user[born_on]" type="datetime-local" min="2014-05-20T00:00:00.000" />
      #
      # Alternatively, you can pass a String formatted as an ISO8601 datetime as
      # the values for "min" and "max."
      #
      #   datetime_field("user", "born_on", min: "2014-05-20T00:00:00")
      #   # => <input id="user_born_on" name="user[born_on]" type="datetime-local" min="2014-05-20T00:00:00.000" />
      #
      def datetime_field(object_name, method, options = {})
        Tags::DatetimeLocalField.new(object_name, method, self, options).render
      end

      alias datetime_local_field datetime_field

      # Returns a text_field of type "month".
      #
      #   month_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="month" />
      #
      # The default value is generated by trying to call +strftime+ with "%Y-%m"
      # on the object's value, which makes it behave as expected for instances
      # of DateTime and ActiveSupport::TimeWithZone.
      #
      #   @user.born_on = Date.new(1984, 1, 27)
      #   month_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="date" value="1984-01" />
      #
      def month_field(object_name, method, options = {})
        Tags::MonthField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "week".
      #
      #   week_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="week" />
      #
      # The default value is generated by trying to call +strftime+ with "%Y-W%W"
      # on the object's value, which makes it behave as expected for instances
      # of DateTime and ActiveSupport::TimeWithZone.
      #
      #   @user.born_on = Date.new(1984, 5, 12)
      #   week_field("user", "born_on")
      #   # => <input id="user_born_on" name="user[born_on]" type="date" value="1984-W19" />
      #
      def week_field(object_name, method, options = {})
        Tags::WeekField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "url".
      #
      #   url_field("user", "homepage")
      #   # => <input id="user_homepage" name="user[homepage]" type="url" />
      #
      def url_field(object_name, method, options = {})
        Tags::UrlField.new(object_name, method, self, options).render
      end

      # Returns a text_field of type "email".
      #
      #   email_field("user", "address")
      #   # => <input id="user_address" name="user[address]" type="email" />
      #
      def email_field(object_name, method, options = {})
        Tags::EmailField.new(object_name, method, self, options).render
      end

      # Returns an input tag of type "number".
      #
      # ==== Options
      # * Accepts same options as number_field_tag
      def number_field(object_name, method, options = {})
        Tags::NumberField.new(object_name, method, self, options).render
      end

      # Returns an input tag of type "range".
      #
      # ==== Options
      # * Accepts same options as range_field_tag
      def range_field(object_name, method, options = {})
        Tags::RangeField.new(object_name, method, self, options).render
      end

      private

        def instantiate_builder(record_name, record_object, options)
          case record_name
          when String, Symbol
            object = record_object
            object_name = record_name
          else
            object = record_name
            object_name = model_name_from_record_or_class(object).param_key
          end

          builder = options[:builder] || default_form_builder_class
          builder.new(object_name, object, self, options)
        end

        def default_form_builder_class
          builder = default_form_builder || ActionView::Base.default_form_builder
          builder.respond_to?(:constantize) ? builder.constantize : builder
        end
    end

    # A +FormBuilder+ object is associated with a particular model object and
    # allows you to generate fields associated with the model object. The
    # +FormBuilder+ object is yielded when using +form_for+ or +fields_for+.
    # For example:
    #
    #   <%= form_for @person do |person_form| %>
    #     Name: <%= person_form.text_field :name %>
    #     Admin: <%= person_form.check_box :admin %>
    #   <% end %>
    #
    # In the above block, a +FormBuilder+ object is yielded as the
    # +person_form+ variable. This allows you to generate the +text_field+
    # and +check_box+ fields by specifying their eponymous methods, which
    # modify the underlying template and associates the +@person+ model object
    # with the form.
    #
    # The +FormBuilder+ object can be thought of as serving as a proxy for the
    # methods in the +FormHelper+ module. This class, however, allows you to
    # call methods with the model object you are building the form for.
    #
    # You can create your own custom FormBuilder templates by subclassing this
    # class. For example:
    #
    #   class MyFormBuilder < ActionView::Helpers::FormBuilder
    #     def div_radio_button(method, tag_value, options = {})
    #       @template.content_tag(:div,
    #         @template.radio_button(
    #           @object_name, method, tag_value, objectify_options(options)
    #         )
    #       )
    #     end
    #   end
    #
    # The above code creates a new method +div_radio_button+ which wraps a div
    # around the new radio button. Note that when options are passed in, you
    # must call +objectify_options+ in order for the model object to get
    # correctly passed to the method. If +objectify_options+ is not called,
    # then the newly created helper will not be linked back to the model.
    #
    # The +div_radio_button+ code from above can now be used as follows:
    #
    #   <%= form_for @person, :builder => MyFormBuilder do |f| %>
    #     I am a child: <%= f.div_radio_button(:admin, "child") %>
    #     I am an adult: <%= f.div_radio_button(:admin, "adult") %>
    #   <% end -%>
    #
    # The standard set of helper methods for form building are located in the
    # +field_helpers+ class attribute.
    class FormBuilder
      include ModelNaming

      # The methods which wrap a form helper call.
      class_attribute :field_helpers
      self.field_helpers = [:fields_for, :label, :text_field, :password_field,
                            :hidden_field, :file_field, :text_area, :check_box,
                            :radio_button, :color_field, :search_field,
                            :telephone_field, :phone_field, :date_field,
                            :time_field, :datetime_field, :datetime_local_field,
                            :month_field, :week_field, :url_field, :email_field,
                            :number_field, :range_field]

      attr_accessor :object_name, :object, :options

      attr_reader :multipart, :index
      alias :multipart? :multipart

      def multipart=(multipart)
        @multipart = multipart

        if parent_builder = @options[:parent_builder]
          parent_builder.multipart = multipart
        end
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

      def initialize(object_name, object, template, options)
        @nested_child_index = {}
        @object_name, @object, @template, @options = object_name, object, template, options
        @default_options = @options ? @options.slice(:index, :namespace) : {}
        if @object_name.to_s.match(/\[\]$/)
          if object ||= @template.instance_variable_get("@#{Regexp.last_match.pre_match}") and object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end
        @multipart = nil
        @index = options[:index] || options[:child_index]
      end

      (field_helpers - [:label, :check_box, :radio_button, :fields_for, :hidden_field, :file_field]).each do |selector|
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

      # Creates a scope around a specific model object like form_for, but
      # doesn't create the form tags themselves. This makes fields_for suitable
      # for specifying additional model objects in the same form.
      #
      # Although the usage and purpose of +fields_for+ is similar to +form_for+'s,
      # its method signature is slightly different. Like +form_for+, it yields
      # a FormBuilder object associated with a particular model object to a block,
      # and within the block allows methods to be called on the builder to
      # generate fields associated with the model object. Fields may reflect
      # a model object in two ways - how they are named (hence how submitted
      # values appear within the +params+ hash in the controller) and what
      # default values are shown when the form the fields appear in is first
      # displayed. In order for both of these features to be specified independently,
      # both an object name (represented by either a symbol or string) and the
      # object itself can be passed to the method separately -
      #
      #   <%= form_for @person do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <%= fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.check_box :admin %>
      #     <% end %>
      #
      #     <%= person_form.submit %>
      #   <% end %>
      #
      # In this case, the checkbox field will be represented by an HTML +input+
      # tag with the +name+ attribute <tt>permission[admin]</tt>, and the submitted
      # value will appear in the controller as <tt>params[:permission][:admin]</tt>.
      # If <tt>@person.permission</tt> is an existing record with an attribute
      # +admin+, the initial state of the checkbox when first displayed will
      # reflect the value of <tt>@person.permission.admin</tt>.
      #
      # Often this can be simplified by passing just the name of the model
      # object to +fields_for+ -
      #
      #   <%= fields_for :permission do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # ...in which case, if <tt>:permission</tt> also happens to be the name of an
      # instance variable <tt>@permission</tt>, the initial state of the input
      # field will reflect the value of that variable's attribute <tt>@permission.admin</tt>.
      #
      # Alternatively, you can pass just the model object itself (if the first
      # argument isn't a string or symbol +fields_for+ will realize that the
      # name has been omitted) -
      #
      #   <%= fields_for @person.permission do |permission_fields| %>
      #     Admin?: <%= permission_fields.check_box :admin %>
      #   <% end %>
      #
      # and +fields_for+ will derive the required name of the field from the
      # _class_ of the model object, e.g. if <tt>@person.permission</tt>, is
      # of class +Permission+, the field will still be named <tt>permission[admin]</tt>.
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
      #     accepts_nested_attributes_for :address, allow_destroy: true
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
      # If you want to destroy any of the associated models through the
      # form, you have to enable it first using the <tt>:allow_destroy</tt>
      # option for +accepts_nested_attributes_for+:
      #
      #   class Person < ActiveRecord::Base
      #     has_many :projects
      #     accepts_nested_attributes_for :projects, allow_destroy: true
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
      #
      # When a collection is used you might want to know the index of each
      # object into the array. For this purpose, the <tt>index</tt> method
      # is available in the FormBuilder object.
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Project #<%= project_fields.index %>
      #       ...
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # Note that fields_for will automatically generate a hidden field
      # to store the ID of the record. There are circumstances where this
      # hidden field is not needed and you can pass <tt>include_id: false</tt>
      # to prevent fields_for from rendering it automatically.
      def fields_for(record_name, record_object = nil, fields_options = {}, &block)
        fields_options, record_object = record_object, nil if record_object.is_a?(Hash) && record_object.extractable_options?
        fields_options[:builder] ||= options[:builder]
        fields_options[:namespace] = options[:namespace]
        fields_options[:parent_builder] = self

        case record_name
        when String, Symbol
          if nested_attributes_association?(record_name)
            return fields_for_with_nested_attributes(record_name, record_object, fields_options, block)
          end
        else
          record_object = record_name.is_a?(Array) ? record_name.last : record_name
          record_name   = model_name_from_record_or_class(record_object).param_key
        end

        index = if options.has_key?(:index)
          options[:index]
        elsif defined?(@auto_index)
          self.object_name = @object_name.to_s.sub(/\[\]$/,"")
          @auto_index
        end

        record_name = if index
                        "#{object_name}[#{index}][#{record_name}]"
                      elsif record_name.to_s.end_with?('[]')
                        record_name = record_name.to_s.sub(/(.*)\[\]$/, "[\\1][#{record_object.id}]")
                        "#{object_name}#{record_name}"
                      else
                        "#{object_name}[#{record_name}]"
                      end
        fields_options[:child_index] = index

        @template.fields_for(record_name, record_object, fields_options, &block)
      end

      # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). The text of label will default to the attribute name unless a translation
      # is found in the current I18n locale (through helpers.label.<modelname>.<attribute>) or you specify it explicitly.
      # Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
      # onto the HTML as an HTML element attribute as in the example shown, except for the <tt>:value</tt> option, which is designed to
      # target labels for radio_button tags (where the value is used in the ID of the input tag).
      #
      # ==== Examples
      #   label(:title)
      #   # => <label for="post_title">Title</label>
      #
      # You can localize your labels based on model and attribute names.
      # For example you can define the following in your locale (e.g. en.yml)
      #
      #   helpers:
      #     label:
      #       post:
      #         body: "Write your entire text here"
      #
      # Which then will result in
      #
      #   label(:body)
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
      #   label(:cost)
      #   # => <label for="post_cost">Total cost</label>
      #
      #   label(:title, "A short title")
      #   # => <label for="post_title">A short title</label>
      #
      #   label(:title, "A short title", class: "title_label")
      #   # => <label for="post_title" class="title_label">A short title</label>
      #
      #   label(:privacy, "Public Post", value: "public")
      #   # => <label for="post_privacy_public">Public Post</label>
      #
      #   label(:terms) do
      #     raw('Accept <a href="/terms">Terms</a>.')
      #   end
      #   # => <label for="post_terms">Accept <a href="/terms">Terms</a>.</label>
      def label(method, text = nil, options = {}, &block)
        @template.label(@object_name, method, text, objectify_options(options), &block)
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
      #   @invoice.update(params[:invoice])
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
      #   <%= fields_for "project[invoice_attributes][]", invoice, index: nil do |form| %>
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
      #   # Let's say that @post.validated? is 1:
      #   check_box("validated")
      #   # => <input name="post[validated]" type="hidden" value="0" />
      #   #    <input checked="checked" type="checkbox" id="post_validated" name="post[validated]" value="1" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   check_box("gooddog", {}, "yes", "no")
      #   # => <input name="puppy[gooddog]" type="hidden" value="no" />
      #   #    <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #
      #   # Let's say that @eula.accepted is "no":
      #   check_box("accepted", { class: 'eula_check' }, "yes", "no")
      #   # => <input name="eula[accepted]" type="hidden" value="no" />
      #   #    <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
      def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked.
      #
      # To force the radio button to be checked pass <tt>checked: true</tt> in the
      # +options+ hash. You may pass HTML options there as well.
      #
      #   # Let's say that @post.category returns "rails":
      #   radio_button("category", "rails")
      #   radio_button("category", "java")
      #   # => <input type="radio" id="post_category_rails" name="post[category]" value="rails" checked="checked" />
      #   #    <input type="radio" id="post_category_java" name="post[category]" value="java" />
      #
      #   # Let's say that @user.category returns "no":
      #   radio_button("receive_newsletter", "yes")
      #   radio_button("receive_newsletter", "no")
      #   # => <input type="radio" id="user_receive_newsletter_yes" name="user[receive_newsletter]" value="yes" />
      #   #    <input type="radio" id="user_receive_newsletter_no" name="user[receive_newsletter]" value="no" checked="checked" />
      def radio_button(method, tag_value, options = {})
        @template.radio_button(@object_name, method, tag_value, objectify_options(options))
      end

      # Returns a hidden input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   # Let's say that @signup.pass_confirm returns true:
      #   hidden_field(:pass_confirm)
      #   # => <input type="hidden" id="signup_pass_confirm" name="signup[pass_confirm]" value="true" />
      #
      #   # Let's say that @post.tag_list returns "blog, ruby":
      #   hidden_field(:tag_list)
      #   # => <input type="hidden" id="post_tag_list" name="post[tag_list]" value="blog, ruby" />
      #
      #   # Let's say that @user.token returns "abcde":
      #   hidden_field(:token)
      #   # => <input type="hidden" id="user_token" name="user[token]" value="abcde" />
      #
      def hidden_field(method, options = {})
        @emitted_hidden_id = true if method == :id
        @template.hidden_field(@object_name, method, objectify_options(options))
      end

      # Returns a file upload input tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # Using this method inside a +form_for+ block will set the enclosing form's encoding to <tt>multipart/form-data</tt>.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:multiple</tt> - If set to true, *in most updated browsers* the user will be allowed to select multiple files.
      # * <tt>:accept</tt> - If set to one or multiple mime-types, the user will be suggested a filter when choosing a file. You still need to set up model validations.
      #
      # ==== Examples
      #   # Let's say that @user has avatar:
      #   file_field(:avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   # Let's say that @post has image:
      #   file_field(:image, :multiple => true)
      #   # => <input type="file" id="post_image" name="post[image][]" multiple="multiple" />
      #
      #   # Let's say that @post has attached:
      #   file_field(:attached, accept: 'text/html')
      #   # => <input accept="text/html" type="file" id="post_attached" name="post[attached]" />
      #
      #   # Let's say that @post has image:
      #   file_field(:image, accept: 'image/png,image/gif,image/jpeg')
      #   # => <input type="file" id="post_image" name="post[image]" accept="image/png,image/gif,image/jpeg" />
      #
      #   # Let's say that @attachment has file:
      #   file_field(:file, class: 'file_input')
      #   # => <input type="file" id="attachment_file" name="attachment[file]" class="file_input" />
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
      # button label, otherwise, it uses "Update Post".
      #
      # Those labels can be customized using I18n, under the helpers.submit key
      # (the same as submit helper) and accept the %{model} as translation interpolation:
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
      # ==== Examples
      #   button("Create post")
      #   # => <button name='button' type='submit'>Create post</button>
      #
      #   button do
      #     content_tag(:strong, 'Ask me!')
      #   end
      #   # => <button name='button' type='submit'>
      #   #      <strong>Ask me!</strong>
      #   #    </button>
      #
      def button(value = nil, options = {}, &block)
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.button_tag(value, options, &block)
      end

      def emitted_hidden_id?
        @emitted_hidden_id ||= nil
      end

      private
        def objectify_options(options)
          @default_options.merge(options.merge(object: @object))
        end

        def submit_default_value
          object = convert_to_model(@object)
          key    = object ? (object.persisted? ? :update : :create) : :submit

          model = if object.respond_to?(:model_name)
            object.model_name.human
          else
            @object_name.to_s.humanize
          end

          defaults = []
          defaults << :"helpers.submit.#{object_name}.#{key}"
          defaults << :"helpers.submit.#{key}"
          defaults << "#{key.to_s.humanize} #{model}"

          I18n.t(defaults.shift, model: model, default: defaults)
        end

        def nested_attributes_association?(association_name)
          @object.respond_to?("#{association_name}_attributes=")
        end

        def fields_for_with_nested_attributes(association_name, association, options, block)
          name = "#{object_name}[#{association_name}_attributes]"
          association = convert_to_model(association)

          if association.respond_to?(:persisted?)
            association = [association] if @object.send(association_name).respond_to?(:to_ary)
          elsif !association.respond_to?(:to_ary)
            association = @object.send(association_name)
          end

          if association.respond_to?(:to_ary)
            explicit_child_index = options[:child_index]
            output = ActiveSupport::SafeBuffer.new
            association.each do |child|
              if explicit_child_index
                options[:child_index] = explicit_child_index.call if explicit_child_index.respond_to?(:call)
              else
                options[:child_index] = nested_child_index(name)
              end
              output << fields_for_nested_model("#{name}[#{options[:child_index]}]", child, options, block)
            end
            output
          elsif association
            fields_for_nested_model(name, association, options, block)
          end
        end

        def fields_for_nested_model(name, object, fields_options, block)
          object = convert_to_model(object)
          emit_hidden_id = object.persisted? && fields_options.fetch(:include_id) {
            options.fetch(:include_id, true)
          }

          @template.fields_for(name, object, fields_options) do |f|
            output = @template.capture(f, &block)
            output.concat f.hidden_field(:id) if output && emit_hidden_id && !f.emitted_hidden_id?
            output
          end
        end

        def nested_child_index(name)
          @nested_child_index[name] ||= -1
          @nested_child_index[name] += 1
        end
    end
  end

  ActiveSupport.on_load(:action_view) do
    cattr_accessor(:default_form_builder, instance_writer: false, instance_reader: false) do
      ::ActionView::Helpers::FormBuilder
    end
  end
end

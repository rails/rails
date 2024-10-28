# frozen_string_literal: true

require "cgi"
require "action_view/helpers/date_helper"
require "action_view/helpers/url_helper"
require "action_view/helpers/form_tag_helper"
require "action_view/helpers/active_model_helper"
require "action_view/model_naming"
require "action_view/record_identifier"
require "active_support/code_generator"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/hash/slice"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/string/inflections"

module ActionView
  module Helpers # :nodoc:
    # = Action View Form \Helpers
    #
    # Form helpers are designed to make working with resources much easier
    # compared to using vanilla HTML.
    #
    # Typically, a form designed to create or update a resource reflects the
    # identity of the resource in several ways: (i) the URL that the form is
    # sent to (the form element's +action+ attribute) should result in a request
    # being routed to the appropriate controller action (with the appropriate <tt>:id</tt>
    # parameter in the case of an existing resource), (ii) input fields should
    # be named in such a way that in the controller their values appear in the
    # appropriate places within the +params+ hash, and (iii) for an existing record,
    # when the form is initially displayed, input fields corresponding to attributes
    # of the resource should show the current values of those attributes.
    #
    # In \Rails, this is usually achieved by creating the form using either
    # +form_with+ or +form_for+ and a number of related helper methods. These
    # methods generate an appropriate <tt>form</tt> tag and yield a form
    # builder object that knows the model the form is about. Input fields are
    # created by calling methods defined on the form builder, which means they
    # are able to generate the appropriate names and default values
    # corresponding to the model attributes, as well as convenient IDs, etc.
    # Conventions in the generated field names allow controllers to receive form
    # data nicely structured in +params+ with no effort on your side.
    #
    # For example, to create a new person you typically set up a new instance of
    # +Person+ in the <tt>PeopleController#new</tt> action, <tt>@person</tt>, and
    # in the view template pass that object to +form_with+ or +form_for+:
    #
    #   <%= form_with model: @person do |f| %>
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
      # how much you wish to rely on \Rails to infer automatically from the model
      # how the form should be constructed. For a generic model object, a form
      # can be created by passing +form_for+ a string or symbol representing
      # the object we are concerned with:
      #
      #   <%= form_for :person do |f| %>
      #     First name: <%= f.text_field :first_name %><br />
      #     Last name : <%= f.text_field :last_name %><br />
      #     Biography : <%= f.textarea :biography %><br />
      #     Admin?    : <%= f.checkbox :admin %><br />
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
      #   sent back to the current URL (We will describe below an alternative
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
      #   JavaScript drivers to control the submit behavior.
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
      #     Biography : <%= textarea :person, :biography %>
      #     Admin?    : <%= checkbox_tag "person[admin]", "1", @person.company.admin? %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # This also works for the methods in FormOptionsHelper and DateHelper that
      # are designed to work with an object as base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
      #
      # === #form_for with a model object
      #
      # In the examples above, the object to be created or edited was
      # represented by a symbol passed to +form_for+, and we noted that
      # a string can also be used equivalently. It is also possible, however,
      # to pass a model object itself to +form_for+. For example, if <tt>@article</tt>
      # is an existing record you wish to edit, you can create the form using
      #
      #   <%= form_for @article do |f| %>
      #     ...
      #   <% end %>
      #
      # This behaves in almost the same way as outlined previously, with a
      # couple of small exceptions. First, the prefix used to name the input
      # elements within the form (hence the key that denotes them in the +params+
      # hash) is actually derived from the object's _class_, e.g. <tt>params[:article]</tt>
      # if the object's class is +Article+. However, this can be overwritten using
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
      # variable. So, for example, if we had a _local_ variable +article+
      # representing an existing record,
      #
      #   <%= form_for article do |f| %>
      #     ...
      #   <% end %>
      #
      # would produce a form with fields whose initial state reflect the current
      # values of the attributes of +article+.
      #
      # === Resource-oriented style
      #
      # In the examples just shown, although not indicated explicitly, we still
      # need to use the <tt>:url</tt> option in order to specify where the
      # form is going to be sent. However, further simplification is possible
      # if the record passed to +form_for+ is a _resource_, i.e. it corresponds
      # to a set of RESTful routes, e.g. defined using the +resources+ method
      # in <tt>config/routes.rb</tt>. In this case \Rails will simply infer the
      # appropriate URL from the record itself. For example,
      #
      #   <%= form_for @article do |f| %>
      #     ...
      #   <% end %>
      #
      # is then equivalent to something like:
      #
      #   <%= form_for @article, as: :article, url: article_path(@article), method: :patch, html: { class: "edit_article", id: "edit_article_45" } do |f| %>
      #     ...
      #   <% end %>
      #
      # And for a new record
      #
      #   <%= form_for(Article.new) do |f| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <%= form_for @article, as: :article, url: articles_path, html: { class: "new_article", id: "new_article" } do |f| %>
      #     ...
      #   <% end %>
      #
      # However you can still overwrite individual conventions, such as:
      #
      #   <%= form_for(@article, url: super_articles_path) do |f| %>
      #     ...
      #   <% end %>
      #
      # You can omit the <tt>action</tt> attribute by passing <tt>url: false</tt>:
      #
      #   <%= form_for(@article, url: false) do |f| %>
      #     ...
      #   <% end %>
      #
      # You can also set the answer format, like this:
      #
      #   <%= form_for(@article, format: :json) do |f| %>
      #     ...
      #   <% end %>
      #
      # For namespaced routes, like +admin_article_url+:
      #
      #   <%= form_for([:admin, @article]) do |f| %>
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
      # behavior. The form submission will work just like a regular submission as viewed by the receiving
      # side (all elements available in <tt>params</tt>).
      #
      # Example:
      #
      #   <%= form_for(@article, remote: true) do |f| %>
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
      #   <%= form_for(@article, data: { behavior: "autosave" }, html: { name: "go" }) do |f| %>
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
      # In the following example the Article model has many Comments stored within it in a NoSQL database,
      # thus there is no primary key for comments.
      #
      # Example:
      #
      #   <%= form_for(@article) do |f| %>
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
      #     <%= f.textarea :biography %>
      #     <%= f.checkbox :admin %>
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
      #   <%= form_for @invoice, url: external_url, authenticity_token: 'external_token' do |f| %>
      #     ...
      #   <% end %>
      #
      # If you don't want to an authenticity token field be rendered at all just pass <tt>false</tt>:
      #
      #   <%= form_for @invoice, url: external_url, authenticity_token: false do |f| %>
      #     ...
      #   <% end %>
      def form_for(record, options = {}, &block)
        raise ArgumentError, "Missing block" unless block_given?

        case record
        when String, Symbol
          model       = false
          object_name = record
        else
          model       = record
          object      = _object_for_form_builder(record)
          raise ArgumentError, "First argument in form cannot contain nil or be empty" unless object
          object_name = options[:as] || model_name_from_record_or_class(object).param_key
          apply_form_for_options!(object, options)
        end

        remote = options.delete(:remote)

        if remote && !embed_authenticity_token_in_remote_forms && options[:authenticity_token].blank?
          options[:authenticity_token] = false
        end

        options[:model]                               = model
        options[:scope]                               = object_name
        options[:local]                               = !remote
        options[:skip_default_ids]                    = false
        options[:allow_method_names_outside_object]   = options.fetch(:allow_method_names_outside_object, false)

        form_with(**options, &block)
      end

      def apply_form_for_options!(object, options) # :nodoc:
        object = convert_to_model(object)

        as = options[:as]
        namespace = options[:namespace]
        action = object.respond_to?(:persisted?) && object.persisted? ? :edit : :new
        options[:html] ||= {}
        options[:html].reverse_merge!(
          class:  as ? "#{action}_#{as}" : dom_class(object, action),
          id:     (as ? [namespace, action, as] : [namespace, dom_id(object, action)]).compact.join("_").presence,
        )
      end
      private :apply_form_for_options!

      mattr_accessor :form_with_generates_remote_forms, default: true

      mattr_accessor :form_with_generates_ids, default: false

      mattr_accessor :multiple_file_field_include_hidden, default: false

      # Creates a form tag based on mixing URLs, scopes, or models.
      #
      #   # Using just a URL:
      #   <%= form_with url: articles_path do |form| %>
      #     <%= form.text_field :title %>
      #   <% end %>
      #   # =>
      #   <form action="/articles" method="post">
      #     <input type="text" name="title" />
      #   </form>
      #
      #   # With an intentionally empty URL:
      #   <%= form_with url: false do |form| %>
      #     <%= form.text_field :title %>
      #   <% end %>
      #   # =>
      #   <form method="post">
      #     <input type="text" name="title" />
      #   </form>
      #
      #   # Adding a scope prefixes the input field names:
      #   <%= form_with scope: :article, url: articles_path do |form| %>
      #     <%= form.text_field :title %>
      #   <% end %>
      #   # =>
      #   <form action="/articles" method="post">
      #     <input type="text" name="article[title]" />
      #   </form>
      #
      #   # Using a model infers both the URL and scope:
      #   <%= form_with model: Article.new do |form| %>
      #     <%= form.text_field :title %>
      #   <% end %>
      #   # =>
      #   <form action="/articles" method="post">
      #     <input type="text" name="article[title]" />
      #   </form>
      #
      #   # An existing model makes an update form and fills out field values:
      #   <%= form_with model: Article.first do |form| %>
      #     <%= form.text_field :title %>
      #   <% end %>
      #   # =>
      #   <form action="/articles/1" method="post">
      #     <input type="hidden" name="_method" value="patch" />
      #     <input type="text" name="article[title]" value="<the title of the article>" />
      #   </form>
      #   # Though the fields don't have to correspond to model attributes:
      #   <%= form_with model: Cat.new do |form| %>
      #     <%= form.text_field :cats_dont_have_gills %>
      #     <%= form.text_field :but_in_forms_they_can %>
      #   <% end %>
      #   # =>
      #   <form action="/cats" method="post">
      #     <input type="text" name="cat[cats_dont_have_gills]" />
      #     <input type="text" name="cat[but_in_forms_they_can]" />
      #   </form>
      #
      # The parameters in the forms are accessible in controllers according to
      # their name nesting. So inputs named +title+ and <tt>article[title]</tt> are
      # accessible as <tt>params[:title]</tt> and <tt>params[:article][:title]</tt>
      # respectively.
      #
      # For ease of comparison the examples above left out the submit button,
      # as well as the auto generated hidden fields that enable UTF-8 support
      # and adds an authenticity token needed for cross site request forgery
      # protection.
      #
      # === Resource-oriented style
      #
      # In many of the examples just shown, the +:model+ passed to +form_with+
      # is a _resource_. It corresponds to a set of RESTful routes, most likely
      # defined via +resources+ in <tt>config/routes.rb</tt>.
      #
      # So when passing such a model record, \Rails infers the URL and method.
      #
      #   <%= form_with model: @article do |form| %>
      #     ...
      #   <% end %>
      #
      # is then equivalent to something like:
      #
      #   <%= form_with scope: :article, url: article_path(@article), method: :patch do |form| %>
      #     ...
      #   <% end %>
      #
      # And for a new record
      #
      #   <%= form_with model: Article.new do |form| %>
      #     ...
      #   <% end %>
      #
      # is equivalent to something like:
      #
      #   <%= form_with scope: :article, url: articles_path do |form| %>
      #     ...
      #   <% end %>
      #
      # ==== +form_with+ options
      #
      # * <tt>:url</tt> - The URL the form submits to. Akin to values passed to
      #   +url_for+ or +link_to+. For example, you may use a named route
      #   directly. When a <tt>:scope</tt> is passed without a <tt>:url</tt> the
      #   form just submits to the current URL.
      # * <tt>:method</tt> - The method to use when submitting the form, usually
      #   either "get" or "post". If "patch", "put", "delete", or another verb
      #   is used, a hidden input named <tt>_method</tt> is added to
      #   simulate the verb over post.
      # * <tt>:format</tt> - The format of the route the form submits to.
      #   Useful when submitting to another resource type, like <tt>:json</tt>.
      #   Skipped if a <tt>:url</tt> is passed.
      # * <tt>:scope</tt> - The scope to prefix input field names with and
      #   thereby how the submitted parameters are grouped in controllers.
      # * <tt>:namespace</tt> - A namespace for your form to ensure uniqueness of
      #   id attributes on form elements. The namespace attribute will be prefixed
      #   with underscore on the generated HTML id.
      # * <tt>:model</tt> - A model object to infer the <tt>:url</tt> and
      #   <tt>:scope</tt> by, plus fill out input field values.
      #   So if a +title+ attribute is set to "Ahoy!" then a +title+ input
      #   field's value would be "Ahoy!".
      #   If the model is a new record a create form is generated, if an
      #   existing record, however, an update form is generated.
      #   Pass <tt>:scope</tt> or <tt>:url</tt> to override the defaults.
      #   E.g. turn <tt>params[:article]</tt> into <tt>params[:blog]</tt>.
      # * <tt>:authenticity_token</tt> - Authenticity token to use in the form.
      #   Override with a custom authenticity token or pass <tt>false</tt> to
      #   skip the authenticity token field altogether.
      #   Useful when submitting to an external resource like a payment gateway
      #   that might limit the valid fields.
      #   Remote forms may omit the embedded authenticity token by setting
      #   <tt>config.action_view.embed_authenticity_token_in_remote_forms = false</tt>.
      #   This is helpful when fragment-caching the form. Remote forms
      #   get the authenticity token from the <tt>meta</tt> tag, so embedding is
      #   unnecessary unless you support browsers without JavaScript.
      # * <tt>:local</tt> - Whether to use standard HTTP form submission.
      #   When set to <tt>true</tt>, the form is submitted via standard HTTP.
      #   When set to <tt>false</tt>, the form is submitted as a "remote form", which
      #   is handled by \Rails UJS as an XHR. When unspecified, the behavior is derived
      #   from <tt>config.action_view.form_with_generates_remote_forms</tt> where the
      #   config's value is actually the inverse of what <tt>local</tt>'s value would be.
      #   As of \Rails 6.1, that configuration option defaults to <tt>false</tt>
      #   (which has the equivalent effect of passing <tt>local: true</tt>).
      #   In previous versions of \Rails, that configuration option defaults to
      #   <tt>true</tt> (the equivalent of passing <tt>local: false</tt>).
      # * <tt>:skip_enforcing_utf8</tt> - If set to true, a hidden input with name
      #   utf8 is not output.
      # * <tt>:builder</tt> - Override the object used to build the form.
      # * <tt>:id</tt> - Optional HTML id attribute.
      # * <tt>:class</tt> - Optional HTML class attribute.
      # * <tt>:data</tt> - Optional HTML data attributes.
      # * <tt>:html</tt> - Other optional HTML attributes for the form tag.
      #
      # === Examples
      #
      # When not passing a block, +form_with+ just generates an opening form tag.
      #
      #   <%= form_with(model: @article, url: super_articles_path) %>
      #   <%= form_with(model: @article, scope: :blog) %>
      #   <%= form_with(model: @article, format: :json) %>
      #   <%= form_with(model: @article, authenticity_token: false) %> # Disables the token.
      #
      # For namespaced routes, like +admin_article_url+:
      #
      #   <%= form_with(model: [ :admin, @article ]) do |form| %>
      #     ...
      #   <% end %>
      #
      # If your resource has associations defined, for example, you want to add comments
      # to the document given that the routes are set correctly:
      #
      #   <%= form_with(model: [ @document, Comment.new ]) do |form| %>
      #     ...
      #   <% end %>
      #
      # Where <tt>@document = Document.find(params[:id])</tt>.
      #
      # === Mixing with other form helpers
      #
      # While +form_with+ uses a FormBuilder object it's possible to mix and
      # match the stand-alone FormHelper methods and methods
      # from FormTagHelper:
      #
      #   <%= form_with scope: :person do |form| %>
      #     <%= form.text_field :first_name %>
      #     <%= form.text_field :last_name %>
      #
      #     <%= textarea :person, :biography %>
      #     <%= checkbox_tag "person[admin]", "1", @person.company.admin? %>
      #
      #     <%= form.submit %>
      #   <% end %>
      #
      # Same goes for the methods in FormOptionsHelper and DateHelper designed
      # to work with an object as a base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
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
      # === Setting HTML options
      #
      # You can set data attributes directly in a data hash, but HTML options
      # besides id and class must be wrapped in an HTML key:
      #
      #   <%= form_with(model: @article, data: { behavior: "autosave" }, html: { name: "go" }) do |form| %>
      #     ...
      #   <% end %>
      #
      # generates
      #
      #   <form action="/articles/123" method="post" data-behavior="autosave" name="go">
      #     <input name="_method" type="hidden" value="patch" />
      #     ...
      #   </form>
      #
      # === Removing hidden model id's
      #
      # The +form_with+ method automatically includes the model id as a hidden field in the form.
      # This is used to maintain the correlation between the form data and its associated model.
      # Some ORM systems do not use IDs on nested models so in this case you want to be able
      # to disable the hidden id.
      #
      # In the following example the Article model has many Comments stored within it in a NoSQL database,
      # thus there is no primary key for comments.
      #
      #   <%= form_with(model: @article) do |form| %>
      #     <%= form.fields(:comments, skip_id: true) do |fields| %>
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
      #   <%= form_with model: @person, url: { action: "create" }, builder: LabellingFormBuilder do |form| %>
      #     <%= form.text_field :first_name %>
      #     <%= form.text_field :last_name %>
      #     <%= form.textarea :biography %>
      #     <%= form.checkbox :admin %>
      #     <%= form.submit %>
      #   <% end %>
      #
      # In this case, if you use:
      #
      #   <%= render form %>
      #
      # The rendered template is <tt>people/_labelling_form</tt> and the local
      # variable referencing the form builder is called
      # <tt>labelling_form</tt>.
      #
      # The custom FormBuilder class is automatically merged with the options
      # of a nested +fields+ call, unless it's explicitly set.
      #
      # In many cases you will want to wrap the above in another helper, so you
      # could do something like the following:
      #
      #   def labelled_form_with(**options, &block)
      #     form_with(**options.merge(builder: LabellingFormBuilder), &block)
      #   end
      def form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
        raise ArgumentError, "Passed nil to the :model argument, expect an object or false" if model.nil?

        options = { allow_method_names_outside_object: true, skip_default_ids: !form_with_generates_ids }.merge!(options)

        if model
          if url != false
            url ||= if format.nil?
              polymorphic_path(model, {})
            else
              polymorphic_path(model, format: format)
            end
          end

          model   = convert_to_model(_object_for_form_builder(model))
          scope ||= model_name_from_record_or_class(model).param_key
        end

        if block_given?
          builder = instantiate_builder(scope, model, options)
          output  = capture(builder, &block)
          options[:multipart] ||= builder.multipart?

          html_options = html_options_for_form_with(url, model, **options)
          form_tag_with_body(html_options, output)
        else
          html_options = html_options_for_form_with(url, model, **options)
          form_tag_html(html_options)
        end
      end

      # Creates a scope around a specific model object like +form_with+, but
      # doesn't create the form tags themselves. This makes +fields_for+
      # suitable for specifying additional model objects in the same form.
      #
      # Although the usage and purpose of +fields_for+ is similar to +form_with+'s,
      # its method signature is slightly different. Like +form_with+, it yields
      # a FormBuilder object associated with a particular model object to a block,
      # and within the block allows methods to be called on the builder to
      # generate fields associated with the model object. Fields may reflect
      # a model object in two ways - how they are named (hence how submitted
      # values appear within the +params+ hash in the controller) and what
      # default values are shown when the form fields are first displayed.
      # In order for both of these features to be specified independently,
      # both an object name (represented by either a symbol or string) and the
      # object itself can be passed to the method separately -
      #
      #   <%= form_with model: @person do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <%= fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.checkbox :admin %>
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
      #     Admin?: <%= permission_fields.checkbox :admin %>
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
      #     Admin?: <%= permission_fields.checkbox :admin %>
      #   <% end %>
      #
      # and +fields_for+ will derive the required name of the field from the
      # _class_ of the model object, e.g. if <tt>@person.permission</tt>, is
      # of class +Permission+, the field will still be named <tt>permission[admin]</tt>.
      #
      # Note: This also works for the methods in FormOptionsHelper and
      # DateHelper that are designed to work with an object as base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
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
      #   <%= form_with model: @person do |person_form| %>
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
      # model (e.g. 1, '1', true, or 'true'):
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :address do |address_fields| %>
      #       ...
      #       Delete: <%= address_fields.checkbox :_destroy %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      # (e.g. 1, '1', true, or 'true'):
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Delete: <%= project_fields.checkbox :_destroy %>
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # When a collection is used you might want to know the index of each
      # object in the array. For this purpose, the <tt>index</tt> method is
      # available in the FormBuilder object.
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Project #<%= project_fields.index %>
      #       ...
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # Note that fields_for will automatically generate a hidden field
      # to store the ID of the record if it responds to <tt>persisted?</tt>.
      # There are circumstances where this hidden field is not needed and you
      # can pass <tt>include_id: false</tt> to prevent fields_for from
      # rendering it automatically.
      def fields_for(record_name, record_object = nil, options = {}, &block)
        options = { model: record_object, allow_method_names_outside_object: false, skip_default_ids: false }.merge!(options)

        fields(record_name, **options, &block)
      end

      # Scopes input fields with either an explicit scope or model.
      # Like +form_with+ does with <tt>:scope</tt> or <tt>:model</tt>,
      # except it doesn't output the form tags.
      #
      #   # Using a scope prefixes the input field names:
      #   <%= fields :comment do |fields| %>
      #     <%= fields.text_field :body %>
      #   <% end %>
      #   # => <input type="text" name="comment[body]">
      #
      #   # Using a model infers the scope and assigns field values:
      #   <%= fields model: Comment.new(body: "full bodied") do |fields| %>
      #     <%= fields.text_field :body %>
      #   <% end %>
      #   # => <input type="text" name="comment[body]" value="full bodied">
      #
      #   # Using +fields+ with +form_with+:
      #   <%= form_with model: @article do |form| %>
      #     <%= form.text_field :title %>
      #
      #     <%= form.fields :comment do |fields| %>
      #       <%= fields.text_field :body %>
      #     <% end %>
      #   <% end %>
      #
      # Much like +form_with+ a FormBuilder instance associated with the scope
      # or model is yielded, so any generated field names are prefixed with
      # either the passed scope or the scope inferred from the <tt>:model</tt>.
      #
      # === Mixing with other form helpers
      #
      # While +form_with+ uses a FormBuilder object it's possible to mix and
      # match the stand-alone FormHelper methods and methods
      # from FormTagHelper:
      #
      #   <%= fields model: @comment do |fields| %>
      #     <%= fields.text_field :body %>
      #
      #     <%= textarea :commenter, :biography %>
      #     <%= checkbox_tag "comment[all_caps]", "1", @comment.commenter.hulk_mode? %>
      #   <% end %>
      #
      # Same goes for the methods in FormOptionsHelper and DateHelper designed
      # to work with an object as a base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
      def fields(scope = nil, model: nil, **options, &block)
        options = { allow_method_names_outside_object: true, skip_default_ids: !form_with_generates_ids }.merge!(options)

        if model
          model   = _object_for_form_builder(model)
          scope ||= model_name_from_record_or_class(model).param_key
        end

        builder = instantiate_builder(scope, model, options)
        capture(builder, &block)
      end

      # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). The text of label will default to the attribute name unless a translation
      # is found in the current I18n locale (through <tt>helpers.label.<modelname>.<attribute></tt>) or you specify it explicitly.
      # Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
      # onto the HTML as an HTML element attribute as in the example shown, except for the <tt>:value</tt> option, which is designed to
      # target labels for radio_button tags (where the value is used in the ID of the input tag).
      #
      # ==== Examples
      #   label(:article, :title)
      #   # => <label for="article_title">Title</label>
      #
      # You can localize your labels based on model and attribute names.
      # For example you can define the following in your locale (e.g. en.yml)
      #
      #   helpers:
      #     label:
      #       article:
      #         body: "Write your entire text here"
      #
      # Which then will result in
      #
      #   label(:article, :body)
      #   # => <label for="article_body">Write your entire text here</label>
      #
      # Localization can also be based purely on the translation of the attribute-name
      # (if you are using ActiveRecord):
      #
      #   activerecord:
      #     attributes:
      #       article:
      #         cost: "Total cost"
      #
      # <code></code>
      #
      #   label(:article, :cost)
      #   # => <label for="article_cost">Total cost</label>
      #
      #   label(:article, :title, "A short title")
      #   # => <label for="article_title">A short title</label>
      #
      #   label(:article, :title, "A short title", class: "title_label")
      #   # => <label for="article_title" class="title_label">A short title</label>
      #
      #   label(:article, :privacy, "Public Article", value: "public")
      #   # => <label for="article_privacy_public">Public Article</label>
      #
      #   label(:article, :cost) do |translation|
      #     content_tag(:span, translation, class: "cost_label")
      #   end
      #   # => <label for="article_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:article, :cost) do |builder|
      #     content_tag(:span, builder.translation, class: "cost_label")
      #   end
      #   # => <label for="article_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:article, :terms) do
      #     raw('Accept <a href="/terms">Terms</a>.')
      #   end
      #   # => <label for="article_terms">Accept <a href="/terms">Terms</a>.</label>
      def label(object_name, method, content_or_options = nil, options = nil, &block)
        Tags::Label.new(object_name, method, self, content_or_options, options).render(&block)
      end

      # Returns an input tag of the "text" type tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+. These options will be tagged onto the HTML as an HTML element attribute as in the example
      # shown.
      #
      # ==== Examples
      #   text_field(:article, :title, size: 20)
      #   # => <input type="text" id="article_title" name="article[title]" size="20" value="#{@article.title}" />
      #
      #   text_field(:article, :title, class: "create_input")
      #   # => <input type="text" id="article_title" name="article[title]" value="#{@article.title}" class="create_input" />
      #
      #   text_field(:article, :title,  maxlength: 30, class: "title_input")
      #   # => <input type="text" id="article_title" name="article[title]" maxlength="30" size="30" value="#{@article.title}" class="title_input" />
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
      #   hidden_field(:article, :tag_list)
      #   # => <input type="hidden" id="article_tag_list" name="article[tag_list]" value="#{@article.tag_list}" />
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
      # Using this method inside a +form_with+ block will set the enclosing form's encoding to <tt>multipart/form-data</tt>.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:multiple</tt> - If set to true, *in most updated browsers* the user will be allowed to select multiple files.
      # * <tt>:include_hidden</tt> - When <tt>multiple: true</tt> and <tt>include_hidden: true</tt>, the field will be prefixed with an <tt><input type="hidden"></tt> field with an empty value to support submitting an empty collection of files.
      # * <tt>:accept</tt> - If set to one or multiple mime-types, the user will be suggested a filter when choosing a file. You still need to set up model validations.
      #
      # ==== Examples
      #   file_field(:user, :avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   file_field(:article, :image, multiple: true)
      #   # => <input type="file" id="article_image" name="article[image][]" multiple="multiple" />
      #
      #   file_field(:article, :attached, accept: 'text/html')
      #   # => <input accept="text/html" type="file" id="article_attached" name="article[attached]" />
      #
      #   file_field(:article, :image, accept: 'image/png,image/gif,image/jpeg')
      #   # => <input type="file" id="article_image" name="article[image]" accept="image/png,image/gif,image/jpeg" />
      #
      #   file_field(:attachment, :file, class: 'file_input')
      #   # => <input type="file" id="attachment_file" name="attachment[file]" class="file_input" />
      def file_field(object_name, method, options = {})
        options = { include_hidden: multiple_file_field_include_hidden }.merge!(options)

        Tags::FileField.new(object_name, method, self, convert_direct_upload_option_to_url(options.dup)).render
      end

      # Returns a textarea opening and closing tag set tailored for accessing a specified attribute (identified by +method+)
      # on an object assigned to the template (identified by +object+). Additional options on the input tag can be passed as a
      # hash with +options+.
      #
      # ==== Examples
      #   textarea(:article, :body, cols: 20, rows: 40)
      #   # => <textarea cols="20" rows="40" id="article_body" name="article[body]">
      #   #      #{@article.body}
      #   #    </textarea>
      #
      #   textarea(:comment, :text, size: "20x30")
      #   # => <textarea cols="20" rows="30" id="comment_text" name="comment[text]">
      #   #      #{@comment.text}
      #   #    </textarea>
      #
      #   textarea(:application, :notes, cols: 40, rows: 15, class: 'app_input')
      #   # => <textarea cols="40" rows="15" id="application_notes" name="application[notes]" class="app_input">
      #   #      #{@application.notes}
      #   #    </textarea>
      #
      #   textarea(:entry, :body, size: "20x20", disabled: 'disabled')
      #   # => <textarea cols="20" rows="20" id="entry_body" name="entry[body]" disabled="disabled">
      #   #      #{@entry.body}
      #   #    </textarea>
      def textarea(object_name, method, options = {})
        Tags::TextArea.new(object_name, method, self, options).render
      end
      alias_method :text_area, :textarea

      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). This object must be an instance object (@object) and not a local object.
      # It's intended that +method+ returns an integer and if that integer is above zero, then the checkbox is checked.
      # Additional options on the input tag can be passed as a hash with +options+. The +checked_value+ defaults to 1
      # while the default +unchecked_value+ is set to 0 which is convenient for boolean values.
      #
      # ==== Options
      #
      # * Any standard HTML attributes for the tag can be passed in, for example +:class+.
      # * <tt>:checked</tt> - +true+ or +false+ forces the state of the checkbox to be checked or not.
      # * <tt>:include_hidden</tt> - If set to false, the auxiliary hidden field described below will not be generated.
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
      # every check box. The hidden field has the same name and its
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
      #     <%= form.checkbox :paid %>
      #     ...
      #   <% end %>
      #
      # because parameter name repetition is precisely what \Rails seeks to distinguish
      # the elements of the array. For each item with a checked check box you
      # get an extra ghost item with only that attribute, assigned to "0".
      #
      # In that case it is preferable to either use +checkbox_tag+ or to use
      # hashes instead of arrays.
      #
      # ==== Examples
      #
      #   # Let's say that @article.validated? is 1:
      #   checkbox("article", "validated")
      #   # => <input name="article[validated]" type="hidden" value="0" />
      #   #    <input checked="checked" type="checkbox" id="article_validated" name="article[validated]" value="1" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   checkbox("puppy", "gooddog", {}, "yes", "no")
      #   # => <input name="puppy[gooddog]" type="hidden" value="no" />
      #   #    <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #
      #   checkbox("eula", "accepted", { class: 'eula_check' }, "yes", "no")
      #   # => <input name="eula[accepted]" type="hidden" value="no" />
      #   #    <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
      def checkbox(object_name, method, options = {}, checked_value = "1", unchecked_value = "0")
        Tags::CheckBox.new(object_name, method, self, checked_value, unchecked_value, options).render
      end
      alias_method :check_box, :checkbox

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked.
      #
      # To force the radio button to be checked pass <tt>checked: true</tt> in the
      # +options+ hash. You may pass HTML options there as well.
      #
      #   # Let's say that @article.category returns "rails":
      #   radio_button("article", "category", "rails")
      #   radio_button("article", "category", "java")
      #   # => <input type="radio" id="article_category_rails" name="article[category]" value="rails" checked="checked" />
      #   #    <input type="radio" id="article_category_java" name="article[category]" value="java" />
      #
      #   # Let's say that @user.receive_newsletter returns "no":
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
      # on the object's value. If you pass <tt>include_seconds: false</tt>, it will be
      # formatted by trying to call +strftime+ with "%H:%M" on the object's value.
      # It is also possible to override this by passing the "value" option.
      #
      # ==== Options
      #
      # Supports the same options as FormTagHelper#time_field_tag.
      #
      # ==== Examples
      #
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
      # By default, provided times will be formatted including seconds. You can render just the hour
      # and minute by passing <tt>include_seconds: false</tt>. Some browsers will render a simpler UI
      # if you exclude seconds in the timestamp format.
      #
      #   time_field("task", "started_at", value: Time.now, include_seconds: false)
      #   # => <input id="task_started_at" name="task[started_at]" type="time" value="01:00" />
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
      # By default, provided datetimes will be formatted including seconds. You can render just the date, hour,
      # and minute by passing <tt>include_seconds: false</tt>.
      #
      #   @user.born_on = Time.current
      #   datetime_field("user", "born_on", include_seconds: false)
      #   # => <input id="user_born_on" name="user[born_on]" type="datetime-local" value="2014-05-20T14:35" />
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
      #
      # Supports the same options as FormTagHelper#number_field_tag.
      def number_field(object_name, method, options = {})
        Tags::NumberField.new(object_name, method, self, options).render
      end

      # Returns an input tag of type "range".
      #
      # ==== Options
      #
      # Supports the same options as FormTagHelper#range_field_tag.
      def range_field(object_name, method, options = {})
        Tags::RangeField.new(object_name, method, self, options).render
      end

      def _object_for_form_builder(object) # :nodoc:
        object.is_a?(Array) ? object.last : object
      end

      private
        def html_options_for_form_with(url_for_options = nil, model = nil, html: {}, local: !form_with_generates_remote_forms,
          skip_enforcing_utf8: nil, **options)
          html_options = options.slice(:id, :class, :multipart, :method, :data, :authenticity_token).merge!(html)
          html_options[:remote] = html.delete(:remote) || !local
          html_options[:method] ||= :patch if model.respond_to?(:persisted?) && model.persisted?
          if skip_enforcing_utf8.nil?
            if options.key?(:enforce_utf8)
              html_options[:enforce_utf8] = options[:enforce_utf8]
            end
          else
            html_options[:enforce_utf8] = !skip_enforcing_utf8
          end
          html_options_for_form(url_for_options.nil? ? {} : url_for_options, html_options)
        end

        def instantiate_builder(record_name, record_object, options)
          case record_name
          when String, Symbol
            object = record_object
            object_name = record_name
          else
            object = record_name
            object_name = model_name_from_record_or_class(object).param_key if object
          end

          builder = options[:builder] || default_form_builder_class
          builder.new(object_name, object, self, options)
        end

        def default_form_builder_class
          builder = default_form_builder || ActionView::Base.default_form_builder
          builder.respond_to?(:constantize) ? builder.constantize : builder
        end
    end

    # = Action View Form Builder
    #
    # A +FormBuilder+ object is associated with a particular model object and
    # allows you to generate fields associated with the model object. The
    # +FormBuilder+ object is yielded when using +form_with+ or +fields_for+.
    # For example:
    #
    #   <%= form_with model: @person do |person_form| %>
    #     Name: <%= person_form.text_field :name %>
    #     Admin: <%= person_form.checkbox :admin %>
    #   <% end %>
    #
    # In the above block, a +FormBuilder+ object is yielded as the
    # +person_form+ variable. This allows you to generate the +text_field+
    # and +checkbox+ fields by specifying their eponymous methods, which
    # modify the underlying template and associates the <tt>@person</tt> model object
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
    #   <%= form_with model: @person, :builder => MyFormBuilder do |f| %>
    #     I am a child: <%= f.div_radio_button(:admin, "child") %>
    #     I am an adult: <%= f.div_radio_button(:admin, "adult") %>
    #   <% end -%>
    #
    # The standard set of helper methods for form building are located in the
    # +field_helpers+ class attribute.
    class FormBuilder
      include ModelNaming

      # The methods which wrap a form helper call.
      class_attribute :field_helpers, default: [
        :fields_for, :fields, :label, :text_field, :password_field,
        :hidden_field, :file_field, :textarea, :checkbox,
        :radio_button, :color_field, :search_field,
        :telephone_field, :phone_field, :date_field,
        :time_field, :datetime_field, :datetime_local_field,
        :month_field, :week_field, :url_field, :email_field,
        :number_field, :range_field
      ]

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
        @_to_partial_path ||= name.demodulize.underscore.sub!(/_builder$/, "")
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
        @default_options = @options ? @options.slice(:index, :namespace, :skip_default_ids, :allow_method_names_outside_object) : {}
        @default_html_options = @default_options.except(:skip_default_ids, :allow_method_names_outside_object)

        convert_to_legacy_options(@options)

        if @object_name&.end_with?("[]")
          if (object ||= @template.instance_variable_get("@#{@object_name[0..-3]}")) && object.respond_to?(:to_param)
            @auto_index = object.to_param
          else
            raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
          end
        end

        @multipart = nil
        @index = options[:index] || options[:child_index]
      end

      # Generate an HTML <tt>id</tt> attribute value.
      #
      # return the <tt><form></tt> element's <tt>id</tt> attribute.
      #
      #   <%= form_with model: @article do |f| %>
      #     <%# ... %>
      #
      #     <% content_for :sticky_footer do %>
      #       <%= form.button(form: f.id) %>
      #     <% end %>
      #   <% end %>
      #
      # In the example above, the <tt>:sticky_footer</tt> content area will
      # exist outside of the <tt><form></tt> element. By declaring the
      # <tt>form</tt> HTML attribute, we hint to the browser that the generated
      # <tt><button></tt> element should be treated as the <tt><form></tt>
      # element's submit button, regardless of where it exists in the DOM.
      def id
        options.dig(:html, :id) || options[:id]
      end

      # Generate an HTML <tt>id</tt> attribute value for the given field
      #
      # Return the value generated by the <tt>FormBuilder</tt> for the given
      # attribute name.
      #
      #   <%= form_with model: @article do |f| %>
      #     <%= f.label :title %>
      #     <%= f.text_field :title, aria: { describedby: f.field_id(:title, :error) } %>
      #     <%= tag.span("is blank", id: f.field_id(:title, :error) %>
      #   <% end %>
      #
      # In the example above, the <tt><input type="text"></tt> element built by
      # the call to <tt>FormBuilder#text_field</tt> declares an
      # <tt>aria-describedby</tt> attribute referencing the <tt><span></tt>
      # element, sharing a common <tt>id</tt> root (<tt>article_title</tt>, in this
      # case).
      def field_id(method, *suffixes, namespace: @options[:namespace], index: @options[:index])
        @template.field_id(@object_name, method, *suffixes, namespace: namespace, index: index)
      end

      # Generate an HTML <tt>name</tt> attribute value for the given name and
      # field combination
      #
      # Return the value generated by the <tt>FormBuilder</tt> for the given
      # attribute name.
      #
      #   <%= form_with model: @article do |f| %>
      #     <%= f.text_field :title, name: f.field_name(:title, :subtitle) %>
      #     <%# => <input type="text" name="article[title][subtitle]"> %>
      #   <% end %>
      #
      #   <%= form_with model: @article do |f| %>
      #     <%= f.text_field :tag, name: f.field_name(:tag, multiple: true) %>
      #     <%# => <input type="text" name="article[tag][]"> %>
      #   <% end %>
      #
      def field_name(method, *methods, multiple: false, index: @options[:index])
        object_name = @options.fetch(:as) { @object_name }

        @template.field_name(object_name, method, *methods, index: index, multiple: multiple)
      end

      ##
      # :method: text_field
      #
      # :call-seq: text_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#text_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.text_field :name %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: password_field
      #
      # :call-seq: password_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#password_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.password_field :password %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: textarea
      #
      # :call-seq: textarea(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#textarea for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.textarea :detail %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: color_field
      #
      # :call-seq: color_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#color_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.color_field :favorite_color %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: search_field
      #
      # :call-seq: search_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#search_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.search_field :name %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: telephone_field
      #
      # :call-seq: telephone_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#telephone_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.telephone_field :phone %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: phone_field
      #
      # :call-seq: phone_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#phone_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.phone_field :phone %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: date_field
      #
      # :call-seq: date_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#date_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.date_field :born_on %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: time_field
      #
      # :call-seq: time_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#time_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.time_field :born_at %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: datetime_field
      #
      # :call-seq: datetime_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#datetime_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.datetime_field :graduation_day %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: datetime_local_field
      #
      # :call-seq: datetime_local_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#datetime_local_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.datetime_local_field :graduation_day %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: month_field
      #
      # :call-seq: month_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#month_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.month_field :birthday_month %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: week_field
      #
      # :call-seq: week_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#week_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.week_field :birthday_week %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: url_field
      #
      # :call-seq: url_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#url_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.url_field :homepage %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: email_field
      #
      # :call-seq: email_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#email_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.email_field :address %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: number_field
      #
      # :call-seq: number_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#number_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.number_field :age %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ##
      # :method: range_field
      #
      # :call-seq: range_field(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#range_field for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.range_field :age %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.

      ActiveSupport::CodeGenerator.batch(self, __FILE__, __LINE__) do |code_generator|
        (field_helpers - [:label, :checkbox, :radio_button, :fields_for, :fields, :hidden_field, :file_field]).each do |selector|
            code_generator.class_eval do |batch|
              batch <<
                "def #{selector}(method, options = {})" <<
                "  @template.#{selector}(@object_name, method, objectify_options(options))" <<
                "end"
            end
          end
      end
      alias_method :text_area, :textarea

      # Creates a scope around a specific model object like +form_with+, but
      # doesn't create the form tags themselves. This makes +fields_for+
      # suitable for specifying additional model objects in the same form.
      #
      # Although the usage and purpose of +fields_for+ is similar to +form_with+'s,
      # its method signature is slightly different. Like +form_with+, it yields
      # a FormBuilder object associated with a particular model object to a block,
      # and within the block allows methods to be called on the builder to
      # generate fields associated with the model object. Fields may reflect
      # a model object in two ways - how they are named (hence how submitted
      # values appear within the +params+ hash in the controller) and what
      # default values are shown when the form fields are first displayed.
      # In order for both of these features to be specified independently,
      # both an object name (represented by either a symbol or string) and the
      # object itself can be passed to the method separately -
      #
      #   <%= form_with model: @person do |person_form| %>
      #     First name: <%= person_form.text_field :first_name %>
      #     Last name : <%= person_form.text_field :last_name %>
      #
      #     <%= fields_for :permission, @person.permission do |permission_fields| %>
      #       Admin?  : <%= permission_fields.checkbox :admin %>
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
      #     Admin?: <%= permission_fields.checkbox :admin %>
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
      #     Admin?: <%= permission_fields.checkbox :admin %>
      #   <% end %>
      #
      # and +fields_for+ will derive the required name of the field from the
      # _class_ of the model object, e.g. if <tt>@person.permission</tt>, is
      # of class +Permission+, the field will still be named <tt>permission[admin]</tt>.
      #
      # Note: This also works for the methods in FormOptionsHelper and
      # DateHelper that are designed to work with an object as base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
      #
      # +fields_for+ tries to be smart about parameters, but it can be confused if both
      # name and value parameters are provided and the provided value has the shape of an
      # option Hash. To remove the ambiguity, explicitly pass an option Hash, even if empty.
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= fields_for :permission, @person.permission, {} do |permission_fields| %>
      #       Admin?: <%= checkbox_tag permission_fields.field_name(:admin), @person.permission[:admin] %>
      #     <% end %>
      #     ...
      #   <% end %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      # model (e.g. 1, '1', true, or 'true'):
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :address do |address_fields| %>
      #       ...
      #       Delete: <%= address_fields.checkbox :_destroy %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      #   <%= form_with model: @person do |person_form| %>
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
      # (e.g. 1, '1', true, or 'true'):
      #
      #   <%= form_with model: @person do |person_form| %>
      #     ...
      #     <%= person_form.fields_for :projects do |project_fields| %>
      #       Delete: <%= project_fields.checkbox :_destroy %>
      #     <% end %>
      #     ...
      #   <% end %>
      #
      # When a collection is used you might want to know the index of each
      # object in the array. For this purpose, the <tt>index</tt> method
      # is available in the FormBuilder object.
      #
      #   <%= form_with model: @person do |person_form| %>
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
      def fields_for(record_name, record_object = nil, fields_options = nil, &block)
        fields_options, record_object = record_object, nil if fields_options.nil? && record_object.is_a?(Hash) && record_object.extractable_options?
        fields_options ||= {}
        fields_options[:builder] ||= options[:builder]
        fields_options[:namespace] = options[:namespace]
        fields_options[:parent_builder] = self

        case record_name
        when String, Symbol
          if nested_attributes_association?(record_name)
            return fields_for_with_nested_attributes(record_name, record_object, fields_options, block)
          end
        else
          record_object = @template._object_for_form_builder(record_name)
          record_name   = model_name_from_record_or_class(record_object).param_key
        end

        object_name = @object_name
        index = if options.has_key?(:index)
          options[:index]
        elsif defined?(@auto_index)
          object_name = object_name.to_s.delete_suffix("[]")
          @auto_index
        end

        record_name = if index
          "#{object_name}[#{index}][#{record_name}]"
        elsif record_name.end_with?("[]")
          "#{object_name}[#{record_name[0..-3]}][#{record_object.id}]"
        else
          "#{object_name}[#{record_name}]"
        end
        fields_options[:child_index] = index

        @template.fields_for(record_name, record_object, fields_options, &block)
      end

      # See the docs for the ActionView::Helpers::FormHelper#fields helper method.
      def fields(scope = nil, model: nil, **options, &block)
        options[:allow_method_names_outside_object] = true
        options[:skip_default_ids] = !FormHelper.form_with_generates_ids

        convert_to_legacy_options(options)

        fields_for(scope || model, model, options, &block)
      end

      # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). The text of label will default to the attribute name unless a translation
      # is found in the current I18n locale (through <tt>helpers.label.<modelname>.<attribute></tt>) or you specify it explicitly.
      # Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
      # onto the HTML as an HTML element attribute as in the example shown, except for the <tt>:value</tt> option, which is designed to
      # target labels for radio_button tags (where the value is used in the ID of the input tag).
      #
      # ==== Examples
      #   label(:title)
      #   # => <label for="article_title">Title</label>
      #
      # You can localize your labels based on model and attribute names.
      # For example you can define the following in your locale (e.g. en.yml)
      #
      #   helpers:
      #     label:
      #       article:
      #         body: "Write your entire text here"
      #
      # Which then will result in
      #
      #   label(:body)
      #   # => <label for="article_body">Write your entire text here</label>
      #
      # Localization can also be based purely on the translation of the attribute-name
      # (if you are using ActiveRecord):
      #
      #   activerecord:
      #     attributes:
      #       article:
      #         cost: "Total cost"
      #
      # <code></code>
      #
      #   label(:cost)
      #   # => <label for="article_cost">Total cost</label>
      #
      #   label(:title, "A short title")
      #   # => <label for="article_title">A short title</label>
      #
      #   label(:title, "A short title", class: "title_label")
      #   # => <label for="article_title" class="title_label">A short title</label>
      #
      #   label(:privacy, "Public Article", value: "public")
      #   # => <label for="article_privacy_public">Public Article</label>
      #
      #   label(:cost) do |translation|
      #     content_tag(:span, translation, class: "cost_label")
      #   end
      #   # => <label for="article_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:cost) do |builder|
      #     content_tag(:span, builder.translation, class: "cost_label")
      #   end
      #   # => <label for="article_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:cost) do |builder|
      #     content_tag(:span, builder.translation, class: [
      #       "cost_label",
      #       ("error_label" if builder.object.errors.include?(:cost))
      #     ])
      #   end
      #   # => <label for="article_cost"><span class="cost_label error_label">Total cost</span></label>
      #
      #   label(:terms) do
      #     raw('Accept <a href="/terms">Terms</a>.')
      #   end
      #   # => <label for="article_terms">Accept <a href="/terms">Terms</a>.</label>
      def label(method, text = nil, options = {}, &block)
        @template.label(@object_name, method, text, objectify_options(options), &block)
      end

      # Returns a checkbox tag tailored for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). This object must be an instance object (@object) and not a local object.
      # It's intended that +method+ returns an integer and if that integer is above zero, then the checkbox is checked.
      # Additional options on the input tag can be passed as a hash with +options+. The +checked_value+ defaults to 1
      # while the default +unchecked_value+ is set to 0 which is convenient for boolean values.
      #
      # ==== Options
      #
      # * Any standard HTML attributes for the tag can be passed in, for example +:class+.
      # * <tt>:checked</tt> - +true+ or +false+ forces the state of the checkbox to be checked or not.
      # * <tt>:include_hidden</tt> - If set to false, the auxiliary hidden field described below will not be generated.
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
      # every check box. The hidden field has the same name and its
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
      #     <%= form.checkbox :paid %>
      #     ...
      #   <% end %>
      #
      # because parameter name repetition is precisely what \Rails seeks to distinguish
      # the elements of the array. For each item with a checked check box you
      # get an extra ghost item with only that attribute, assigned to "0".
      #
      # In that case it is preferable to either use +checkbox_tag+ or to use
      # hashes instead of arrays.
      #
      # ==== Examples
      #
      #   # Let's say that @article.validated? is 1:
      #   checkbox("validated")
      #   # => <input name="article[validated]" type="hidden" value="0" />
      #   #    <input checked="checked" type="checkbox" id="article_validated" name="article[validated]" value="1" />
      #
      #   # Let's say that @puppy.gooddog is "no":
      #   checkbox("gooddog", {}, "yes", "no")
      #   # => <input name="puppy[gooddog]" type="hidden" value="no" />
      #   #    <input type="checkbox" id="puppy_gooddog" name="puppy[gooddog]" value="yes" />
      #
      #   # Let's say that @eula.accepted is "no":
      #   checkbox("accepted", { class: 'eula_check' }, "yes", "no")
      #   # => <input name="eula[accepted]" type="hidden" value="no" />
      #   #    <input type="checkbox" class="eula_check" id="eula_accepted" name="eula[accepted]" value="yes" />
      def checkbox(method, options = {}, checked_value = "1", unchecked_value = "0")
        @template.checkbox(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end
      alias_method :check_box, :checkbox

      # Returns a radio button tag for accessing a specified attribute (identified by +method+) on an object
      # assigned to the template (identified by +object+). If the current value of +method+ is +tag_value+ the
      # radio button will be checked.
      #
      # To force the radio button to be checked pass <tt>checked: true</tt> in the
      # +options+ hash. You may pass HTML options there as well.
      #
      #   # Let's say that @article.category returns "rails":
      #   radio_button("category", "rails")
      #   radio_button("category", "java")
      #   # => <input type="radio" id="article_category_rails" name="article[category]" value="rails" checked="checked" />
      #   #    <input type="radio" id="article_category_java" name="article[category]" value="java" />
      #
      #   # Let's say that @user.receive_newsletter returns "no":
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
      #   # Let's say that @article.tag_list returns "blog, ruby":
      #   hidden_field(:tag_list)
      #   # => <input type="hidden" id="article_tag_list" name="article[tag_list]" value="blog, ruby" />
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
      # Using this method inside a +form_with+ block will set the enclosing form's encoding to <tt>multipart/form-data</tt>.
      #
      # ==== Options
      # * Creates standard HTML attributes for the tag.
      # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
      # * <tt>:multiple</tt> - If set to true, *in most updated browsers* the user will be allowed to select multiple files.
      # * <tt>:include_hidden</tt> - When <tt>multiple: true</tt> and <tt>include_hidden: true</tt>, the field will be prefixed with an <tt><input type="hidden"></tt> field with an empty value to support submitting an empty collection of files. Since <tt>include_hidden</tt> will default to <tt>config.active_storage.multiple_file_field_include_hidden</tt> if you don't specify <tt>include_hidden</tt>, you will need to pass <tt>include_hidden: false</tt> to prevent submitting an empty collection of files when passing <tt>multiple: true</tt>.
      # * <tt>:accept</tt> - If set to one or multiple mime-types, the user will be suggested a filter when choosing a file. You still need to set up model validations.
      #
      # ==== Examples
      #   # Let's say that @user has avatar:
      #   file_field(:avatar)
      #   # => <input type="file" id="user_avatar" name="user[avatar]" />
      #
      #   # Let's say that @article has image:
      #   file_field(:image, :multiple => true)
      #   # => <input type="file" id="article_image" name="article[image][]" multiple="multiple" />
      #
      #   # Let's say that @article has attached:
      #   file_field(:attached, accept: 'text/html')
      #   # => <input accept="text/html" type="file" id="article_attached" name="article[attached]" />
      #
      #   # Let's say that @article has image:
      #   file_field(:image, accept: 'image/png,image/gif,image/jpeg')
      #   # => <input type="file" id="article_image" name="article[image]" accept="image/png,image/gif,image/jpeg" />
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
      #   <%= form_with model: @article do |f| %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # In the example above, if <tt>@article</tt> is a new record, it will use "Create Article" as
      # submit button label; otherwise, it uses "Update Article".
      #
      # Those labels can be customized using I18n under the +helpers.submit+ key and using
      # <tt>%{model}</tt> for translation interpolation:
      #
      #   en:
      #     helpers:
      #       submit:
      #         create: "Create a %{model}"
      #         update: "Confirm changes to %{model}"
      #
      # It also searches for a key specific to the given object:
      #
      #   en:
      #     helpers:
      #       submit:
      #         article:
      #           create: "Add %{model}"
      #
      def submit(value = nil, options = {})
        value, options = nil, value if value.is_a?(Hash)
        value ||= submit_default_value
        @template.submit_tag(value, options)
      end

      # Add the submit button for the given form. When no value is given, it checks
      # if the object is a new resource or not to create the proper label:
      #
      #   <%= form_with model: @article do |f| %>
      #     <%= f.button %>
      #   <% end %>
      # In the example above, if <tt>@article</tt> is a new record, it will use "Create Article" as
      # button label; otherwise, it uses "Update Article".
      #
      # Those labels can be customized using I18n under the +helpers.submit+ key
      # (the same as submit helper) and using <tt>%{model}</tt> for translation interpolation:
      #
      #   en:
      #     helpers:
      #       submit:
      #         create: "Create a %{model}"
      #         update: "Confirm changes to %{model}"
      #
      # It also searches for a key specific to the given object:
      #
      #   en:
      #     helpers:
      #       submit:
      #         article:
      #           create: "Add %{model}"
      #
      # ==== Examples
      #   button("Create article")
      #   # => <button name='button' type='submit'>Create article</button>
      #
      #   button(:draft, value: true)
      #   # => <button id="article_draft" name="article[draft]" value="true" type="submit">Create article</button>
      #
      #   button do
      #     content_tag(:strong, 'Ask me!')
      #   end
      #   # => <button name='button' type='submit'>
      #   #      <strong>Ask me!</strong>
      #   #    </button>
      #
      #   button do |text|
      #     content_tag(:strong, text)
      #   end
      #   # => <button name='button' type='submit'>
      #   #      <strong>Create article</strong>
      #   #    </button>
      #
      #   button(:draft, value: true) do
      #     content_tag(:strong, "Save as draft")
      #   end
      #   # =>  <button id="article_draft" name="article[draft]" value="true" type="submit">
      #   #       <strong>Save as draft</strong>
      #   #     </button>
      #
      def button(value = nil, options = {}, &block)
        case value
        when Hash
          value, options = nil, value
        when Symbol
          value, options = nil, { name: field_name(value), id: field_id(value) }.merge!(options.to_h)
        end
        value ||= submit_default_value

        if block_given?
          value = @template.capture { yield(value) }
        end

        formmethod = options[:formmethod]
        if formmethod.present? && !/post|get/i.match?(formmethod) && !options.key?(:name) && !options.key?(:value)
          options.merge! formmethod: :post, name: "_method", value: formmethod
        end

        @template.button_tag(value, options)
      end

      def emitted_hidden_id? # :nodoc:
        @emitted_hidden_id ||= nil
      end

      private
        def objectify_options(options)
          result = @default_options.merge(options)
          result[:object] = @object
          result
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
          # Object is a model and it is not overwritten by as and scope option.
          if object.respond_to?(:model_name) && object_name.to_s == model.downcase
            defaults << :"helpers.submit.#{object.model_name.i18n_key}.#{key}"
          else
            defaults << :"helpers.submit.#{object_name}.#{key}"
          end
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
            association = [association] if @object.public_send(association_name).respond_to?(:to_ary)
          elsif !association.respond_to?(:to_ary)
            association = @object.public_send(association_name)
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
              if content = fields_for_nested_model("#{name}[#{options[:child_index]}]", child, options, block)
                output << content
              end
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

        def convert_to_legacy_options(options)
          if options.key?(:skip_id)
            options[:include_id] = !options.delete(:skip_id)
          end
        end
    end
  end

  ActiveSupport.on_load(:action_view) do
    cattr_accessor :default_form_builder, instance_writer: false, instance_reader: false, default: ::ActionView::Helpers::FormBuilder
  end
end

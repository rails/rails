# frozen_string_literal: true

require "action_view/model_naming"

module ActionView
  module Helpers
    # = Action View Form Builder
    #
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
      class_attribute :field_helpers, default: [
        :fields_for, :fields, :label, :text_field, :password_field,
        :hidden_field, :file_field, :text_area, :check_box,
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
      #   <%= form_for @post do |f| %>
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
      #   <%= form_for @post do |f| %>
      #     <%= f.label :title %>
      #     <%= f.text_field :title, aria: { describedby: f.field_id(:title, :error) } %>
      #     <%= tag.span("is blank", id: f.field_id(:title, :error) %>
      #   <% end %>
      #
      # In the example above, the <tt><input type="text"></tt> element built by
      # the call to <tt>FormBuilder#text_field</tt> declares an
      # <tt>aria-describedby</tt> attribute referencing the <tt><span></tt>
      # element, sharing a common <tt>id</tt> root (<tt>post_title</tt>, in this
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
      #   <%= form_for @post do |f| %>
      #     <%= f.text_field :title, name: f.field_name(:title, :subtitle) %>
      #     <%# => <input type="text" name="post[title][subtitle]">
      #   <% end %>
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.field_tag :tag, name: f.field_name(:tag, multiple: true) %>
      #     <%# => <input type="text" name="post[tag][]">
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
      # :method: text_area
      #
      # :call-seq: text_area(method, options = {})
      #
      # Wraps ActionView::Helpers::FormHelper#text_area for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.text_area :detail %>
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

      (field_helpers - [:label, :check_box, :radio_button, :fields_for, :fields, :hidden_field, :file_field]).each do |selector|
          class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{selector}(method, options = {})  # def text_field(method, options = {})
          @template.public_send(               #   @template.public_send(
            #{selector.inspect},               #     :text_field,
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
      # Note: This also works for the methods in FormOptionsHelper and
      # DateHelper that are designed to work with an object as base, like
      # FormOptionsHelper#collection_select and DateHelper#datetime_select.
      #
      # +fields_for+ tries to be smart about parameters, but it can be confused if both
      # name and value parameters are provided and the provided value has the shape of an
      # option Hash. To remove the ambiguity, explicitly pass an option Hash, even if empty.
      #
      #   <%= form_for @person do |person_form| %>
      #     ...
      #     <%= fields_for :permission, @person.permission, {} do |permission_fields| %>
      #       Admin?: <%= check_box_tag permission_fields.field_name(:admin), @person.permission[:admin] %>
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
      # model (e.g. 1, '1', true, or 'true'):
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
      # (e.g. 1, '1', true, or 'true'):
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
      #   label(:cost) do |translation|
      #     content_tag(:span, translation, class: "cost_label")
      #   end
      #   # => <label for="post_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:cost) do |builder|
      #     content_tag(:span, builder.translation, class: "cost_label")
      #   end
      #   # => <label for="post_cost"><span class="cost_label">Total cost</span></label>
      #
      #   label(:cost) do |builder|
      #     content_tag(:span, builder.translation, class: [
      #       "cost_label",
      #       ("error_label" if builder.object.errors.include?(:cost))
      #     ])
      #   end
      #   # => <label for="post_cost"><span class="cost_label error_label">Total cost</span></label>
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
      #     <%= form.check_box :paid %>
      #     ...
      #   <% end %>
      #
      # because parameter name repetition is precisely what \Rails seeks to distinguish
      # the elements of the array. For each item with a checked check box you
      # get an extra ghost item with only that attribute, assigned to "0".
      #
      # In that case it is preferable to either use +check_box_tag+ or to use
      # hashes instead of arrays.
      #
      # ==== Examples
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
      # In the example above, if <tt>@post</tt> is a new record, it will use "Create Post" as
      # submit button label; otherwise, it uses "Update Post".
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
      #         post:
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
      #   <%= form_for @post do |f| %>
      #     <%= f.button %>
      #   <% end %>
      #
      # In the example above, if <tt>@post</tt> is a new record, it will use "Create Post" as
      # button label; otherwise, it uses "Update Post".
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
      #         post:
      #           create: "Add %{model}"
      #
      # ==== Examples
      #   button("Create post")
      #   # => <button name='button' type='submit'>Create post</button>
      #
      #   button(:draft, value: true)
      #   # => <button id="post_draft" name="post[draft]" value="true" type="submit">Create post</button>
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
      #   #      <strong>Create post</strong>
      #   #    </button>
      #
      #   button(:draft, value: true) do
      #     content_tag(:strong, "Save as draft")
      #   end
      #   # =>  <button id="post_draft" name="post[draft]" value="true" type="submit">
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

      # Wraps ActionView::Helpers::FormOptionsHelper#select for form builders:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.select :person_id, Person.all.collect { |p| [ p.name, p.id ] }, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def select(method, choices = nil, options = {}, html_options = {}, &block)
        @template.select(@object_name, method, choices, objectify_options(options), @default_html_options.merge(html_options), &block)
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_select for form builders:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.collection_select :person_id, Author.all, :id, :name_with_initial, prompt: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_select(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#grouped_collection_select for form builders:
      #
      #   <%= form_for @city do |f| %>
      #     <%= f.grouped_collection_select :country_id, @continents, :countries, :name, :id, :name %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
        @template.grouped_collection_select(@object_name, method, collection, group_method, group_label_method, option_key_method, option_value_method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#time_zone_select for form builders:
      #
      #   <%= form_for @user do |f| %>
      #     <%= f.time_zone_select :time_zone, nil, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
        @template.time_zone_select(@object_name, method, priority_zones, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#weekday_select for form builders:
      #
      #   <%= form_for @user do |f| %>
      #     <%= f.weekday_select :weekday, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def weekday_select(method, options = {}, html_options = {})
        @template.weekday_select(@object_name, method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_check_boxes for form builders:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.collection_check_boxes :author_ids, Author.all, :id, :name_with_initial %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_check_boxes(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_check_boxes(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options), &block)
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_radio_buttons for form builders:
      #
      #   <%= form_for @post do |f| %>
      #     <%= f.collection_radio_buttons :author_id, Author.all, :id, :name_with_initial %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_radio_buttons(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options), &block)
      end

      # Wraps ActionView::Helpers::DateHelper#date_select for form builders:
      #
      #   <%= form_for @person do |f| %>
      #     <%= f.date_select :birth_date %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def date_select(method, options = {}, html_options = {})
        @template.date_select(@object_name, method, objectify_options(options), html_options)
      end

      # Wraps ActionView::Helpers::DateHelper#time_select for form builders:
      #
      #   <%= form_for @race do |f| %>
      #     <%= f.time_select :average_lap %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def time_select(method, options = {}, html_options = {})
        @template.time_select(@object_name, method, objectify_options(options), html_options)
      end

      # Wraps ActionView::Helpers::DateHelper#datetime_select for form builders:
      #
      #   <%= form_for @person do |f| %>
      #     <%= f.datetime_select :last_request_at %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def datetime_select(method, options = {}, html_options = {})
        @template.datetime_select(@object_name, method, objectify_options(options), html_options)
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
end

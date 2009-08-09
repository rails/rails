module ActionView
  # There's also a convenience method for rendering sub templates within the current controller that depends on a
  # single object (we call this kind of sub templates for partials). It relies on the fact that partials should
  # follow the naming convention of being prefixed with an underscore -- as to separate them from regular
  # templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render :partial => "account" %>
  #
  # This would render "advertiser/_account.erb" and pass the instance variable @account in as a local variable
  # +account+ to the template for display.
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render :partial => "account", :locals => { :account => @buyer } %>
  #
  #   <% for ad in @advertisements %>
  #     <%= render :partial => "ad", :locals => { :ad => ad } %>
  #   <% end %>
  #
  # This would first render "advertiser/_account.erb" with @buyer passed in as the local variable +account+, then
  # render "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display.
  #
  # == Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and
  # render a sub template for each of the elements. This pattern has been implemented as a single method that
  # accepts an array and renders a partial by the same name as the elements contained within. So the three-lined
  # example in "Using partials" can be rewritten with a single line:
  #
  #   <%= render :partial => "ad", :collection => @advertisements %>
  #
  # This will render "advertiser/_ad.erb" and pass the local variable +ad+ to the template for display. An
  # iteration counter will automatically be made available to the template with a name of the form
  # +partial_name_counter+. In the case of the example above, the template would be fed +ad_counter+.
  #
  # NOTE: Due to backwards compatibility concerns, the collection can't be one of hashes. Normally you'd also
  # just keep domain objects, like Active Records, in there.
  #
  # == Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render :partial => "advertisement/ad", :locals => { :ad => @advertisement } %>
  #
  # This will render the partial "advertisement/_ad.erb" regardless of which controller this is being called from.
  #
  # == Rendering objects with the RecordIdentifier
  #
  # Instead of explicitly naming the location of a partial, you can also let the RecordIdentifier do the work if
  # you're following its conventions for RecordIdentifier#partial_path. Examples:
  #
  #  # @account is an Account instance, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "accounts/account", :locals => { :account => @buyer } %>
  #  <%= render :partial => @account %>
  #
  #  # @posts is an array of Post instances, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "posts/post", :collection => @posts %>
  #  <%= render :partial => @posts %>
  #
  # == Rendering the default case
  #
  # If you're not going to be using any of the options like collections or layouts, you can also use the short-hand
  # defaults of render to render partials. Examples:
  #
  #  # Instead of <%= render :partial => "account" %>
  #  <%= render "account" %>
  #
  #  # Instead of <%= render :partial => "account", :locals => { :account => @buyer } %>
  #  <%= render "account", :account => @buyer %>
  #
  #  # @account is an Account instance, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "accounts/account", :locals => { :account => @account } %>
  #  <%= render(@account) %>
  #
  #  # @posts is an array of Post instances, so it uses the RecordIdentifier to replace
  #  # <%= render :partial => "posts/post", :collection => @posts %>
  #  <%= render(@posts) %>
  #
  # == Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are
  # specified globally for the entire action, but they work in a similar fashion. Imagine a list with two types
  # of users:
  #
  #   <%# app/views/users/index.html.erb &>
  #   Here's the administrator:
  #   <%= render :partial => "user", :layout => "administrator", :locals => { :user => administrator } %>
  #
  #   Here's the editor:
  #   <%= render :partial => "user", :layout => "editor", :locals => { :user => editor } %>
  #
  #   <%# app/views/users/_user.html.erb &>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/_administrator.html.erb &>
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     <%= yield %>
  #   </div>
  #
  #   <%# app/views/users/_editor.html.erb &>
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     <%= yield %>
  #   </div>
  #
  # ...this will return:
  #
  #   Here's the administrator:
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Name: <%= user.name %>
  #   </div>
  #
  #   Here's the editor:
  #   <div id="editor">
  #     Deadline: <%= user.deadline %>
  #     Name: <%= user.name %>
  #   </div>
  #
  # You can also apply a layout to a block within any template:
  #
  #   <%# app/views/users/_chief.html.erb &>
  #   <% render(:layout => "administrator", :locals => { :user => chief }) do %>
  #     Title: <%= chief.title %>
  #   <% end %>
  #
  # ...this will return:
  #
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     Title: <%= chief.name %>
  #   </div>
  #
  # As you can see, the <tt>:locals</tt> hash is shared between both the partial and its layout.
  #
  # If you pass arguments to "yield" then this will be passed to the block. One way to use this is to pass
  # an array to layout and treat it as an enumerable.
  #
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     Budget: $<%= user.budget %>
  #     <%= yield user %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <% render :layout => @users do |user| %>
  #     Title: <%= user.title %>
  #   <% end %>
  #
  # This will render the layout for each user and yield to the block, passing the user, each time.
  #
  # You can also yield multiple times in one layout and use block arguments to differentiate the sections.
  #
  #   <%# app/views/users/_user.html.erb &>
  #   <div class="user">
  #     <%= yield user, :header %>
  #     Budget: $<%= user.budget %>
  #     <%= yield user, :footer %>
  #   </div>
  #
  #   <%# app/views/users/index.html.erb &>
  #   <% render :layout => @users do |user, section| %>
  #     <%- case section when :header -%>
  #       Title: <%= user.title %>
  #     <%- when :footer -%>
  #       Deadline: <%= user.deadline %>
  #     <%- end -%>
  #   <% end %>
  module Partials
    extend ActiveSupport::Concern

    class PartialRenderer
      def self.partial_names
        @partial_names ||= Hash.new {|h,k| h[k] = ActiveSupport::ConcurrentHash.new }
      end

      def self.formats
        @formats ||= Hash.new {|h,k| h[k] = Hash.new{|h,k| h[k] = Hash.new {|h,k| h[k] = {}}}}
      end

      def initialize(view_context, options, block)
        partial = options[:partial]

        @view           = view_context
        @options        = options
        @locals         = options[:locals] || {}
        @block          = block

        # Set up some instance variables to speed up memoizing
        @partial_names  = self.class.partial_names[@view.controller.class]
        @templates      = self.class.formats
        @format         = view_context.formats

        # Set up the object and path
        @object         = partial.is_a?(String) ? options[:object] : partial
        @path           = partial_path(partial)
      end

      def render
        return render_collection if collection

        template = find_template
        render_template(template, @object || @locals[template.variable_name])
      end

      def render_collection
        # Even if no template is rendered, this will ensure that the MIME type
        # for the empty response is the same as the provided template
        @options[:_template] = default_template = find_template

        return nil if collection.blank?

        if @options.key?(:spacer_template)
          spacer = find_template(@options[:spacer_template]).render(@view, @locals)
        end

        segments = []

        collection.each_with_index do |object, index|
          template = default_template || find_template(partial_path(object))
          @locals[template.counter_name] = index
          segments << render_template(template, object)
        end

        segments.join(spacer)
      end

      def render_template(template, object = @object)
        @options[:_template] ||= template

        # TODO: is locals[:object] really necessary?
        @locals[:object] = @locals[template.variable_name] = object
        @locals[@options[:as]] = object if @options[:as]

        content = @view._render_single_template(template, @locals, &@block)
        return content if @block || !@options[:layout]
        find_template(@options[:layout]).render(@view, @locals) { content }
      end


    private
      def collection
        @collection ||= if @object.respond_to?(:to_ary)
          @object
        elsif @options.key?(:collection)
          @options[:collection] || []
        end
      end

      def find_template(path = @path)
        return if !path
        @templates[path][@view.controller_path][@format][I18n.locale] ||= begin
          prefix = @view.controller.controller_path unless path.include?(?/)
          @view.find(path, {:formats => @view.formats}, prefix, true)
        end
      end

      def partial_path(object = @object)
        return object if object.is_a?(String)
        @partial_names[object.class] ||= begin
          return nil unless object.respond_to?(:to_model)

          object.to_model.class.model_name.partial_path.dup.tap do |partial|
            path = @view.controller_path
            partial.insert(0, "#{File.dirname(path)}/") if path.include?(?/)
          end
        end
      end
    end

    def render_partial(options)
      @assigns_added = false
      # TODO: Handle other details here.
      self.formats = options[:_details][:formats] if options[:_details]
      _render_partial(options)
    end

    def _render_partial(options, &block) #:nodoc:
      PartialRenderer.new(self, options, block).render
    end

  end
end

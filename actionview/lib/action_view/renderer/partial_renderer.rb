# frozen_string_literal: true

require "action_view/renderer/partial_renderer/collection_caching"

module ActionView
  # = Action View Partials
  #
  # There's also a convenience method for rendering sub templates within the current controller that depends on a
  # single object (we call this kind of sub templates for partials). It relies on the fact that partials should
  # follow the naming convention of being prefixed with an underscore -- as to separate them from regular
  # templates that could be rendered on their own.
  #
  # In a template for Advertiser#account:
  #
  #  <%= render partial: "account" %>
  #
  # This would render "advertiser/_account.html.erb".
  #
  # In another template for Advertiser#buy, we could have:
  #
  #   <%= render partial: "account", locals: { account: @buyer } %>
  #
  #   <% @advertisements.each do |ad| %>
  #     <%= render partial: "ad", locals: { ad: ad } %>
  #   <% end %>
  #
  # This would first render <tt>advertiser/_account.html.erb</tt> with <tt>@buyer</tt> passed in as the local variable +account+, then
  # render <tt>advertiser/_ad.html.erb</tt> and pass the local variable +ad+ to the template for display.
  #
  # == The :as and :object options
  #
  # By default ActionView::PartialRenderer doesn't have any local variables.
  # The <tt>:object</tt> option can be used to pass an object to the partial. For instance:
  #
  #   <%= render partial: "account", object: @buyer %>
  #
  # would provide the <tt>@buyer</tt> object to the partial, available under the local variable +account+ and is
  # equivalent to:
  #
  #   <%= render partial: "account", locals: { account: @buyer } %>
  #
  # With the <tt>:as</tt> option we can specify a different name for said local variable. For example, if we
  # wanted it to be +user+ instead of +account+ we'd do:
  #
  #   <%= render partial: "account", object: @buyer, as: 'user' %>
  #
  # This is equivalent to
  #
  #   <%= render partial: "account", locals: { user: @buyer } %>
  #
  # == \Rendering a collection of partials
  #
  # The example of partial use describes a familiar pattern where a template needs to iterate over an array and
  # render a sub template for each of the elements. This pattern has been implemented as a single method that
  # accepts an array and renders a partial by the same name as the elements contained within. So the three-lined
  # example in "Using partials" can be rewritten with a single line:
  #
  #   <%= render partial: "ad", collection: @advertisements %>
  #
  # This will render <tt>advertiser/_ad.html.erb</tt> and pass the local variable +ad+ to the template for display. An
  # iteration object will automatically be made available to the template with a name of the form
  # +partial_name_iteration+. The iteration object has knowledge about which index the current object has in
  # the collection and the total size of the collection. The iteration object also has two convenience methods,
  # +first?+ and +last?+. In the case of the example above, the template would be fed +ad_iteration+.
  # For backwards compatibility the +partial_name_counter+ is still present and is mapped to the iteration's
  # +index+ method.
  #
  # The <tt>:as</tt> option may be used when rendering partials.
  #
  # You can specify a partial to be rendered between elements via the <tt>:spacer_template</tt> option.
  # The following example will render <tt>advertiser/_ad_divider.html.erb</tt> between each ad partial:
  #
  #   <%= render partial: "ad", collection: @advertisements, spacer_template: "ad_divider" %>
  #
  # If the given <tt>:collection</tt> is +nil+ or empty, <tt>render</tt> will return +nil+. This will allow you
  # to specify a text which will be displayed instead by using this form:
  #
  #   <%= render(partial: "ad", collection: @advertisements) || "There's no ad to be displayed" %>
  #
  # == \Rendering shared partials
  #
  # Two controllers can share a set of partials and render them like this:
  #
  #   <%= render partial: "advertisement/ad", locals: { ad: @advertisement } %>
  #
  # This will render the partial <tt>advertisement/_ad.html.erb</tt> regardless of which controller this is being called from.
  #
  # == \Rendering objects that respond to +to_partial_path+
  #
  # Instead of explicitly naming the location of a partial, you can also let PartialRenderer do the work
  # and pick the proper path by checking +to_partial_path+ method.
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render partial: "accounts/account", locals: { account: @account} %>
  #  <%= render partial: @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on +to_partial_path+,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render partial: @posts %>
  #
  # == \Rendering the default case
  #
  # If you're not going to be using any of the options like collections or layouts, you can also use the short-hand
  # defaults of render to render partials. Examples:
  #
  #  # Instead of <%= render partial: "account" %>
  #  <%= render "account" %>
  #
  #  # Instead of <%= render partial: "account", locals: { account: @buyer } %>
  #  <%= render "account", account: @buyer %>
  #
  #  # @account.to_partial_path returns 'accounts/account', so it can be used to replace:
  #  # <%= render partial: "accounts/account", locals: { account: @account} %>
  #  <%= render @account %>
  #
  #  # @posts is an array of Post instances, so every post record returns 'posts/post' on +to_partial_path+,
  #  # that's why we can replace:
  #  # <%= render partial: "posts/post", collection: @posts %>
  #  <%= render @posts %>
  #
  # == \Rendering partials with layouts
  #
  # Partials can have their own layouts applied to them. These layouts are different than the ones that are
  # specified globally for the entire action, but they work in a similar fashion. Imagine a list with two types
  # of users:
  #
  #   <%# app/views/users/index.html.erb %>
  #   Here's the administrator:
  #   <%= render partial: "user", layout: "administrator", locals: { user: administrator } %>
  #
  #   Here's the editor:
  #   <%= render partial: "user", layout: "editor", locals: { user: editor } %>
  #
  #   <%# app/views/users/_user.html.erb %>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/_administrator.html.erb %>
  #   <div id="administrator">
  #     Budget: $<%= user.budget %>
  #     <%= yield %>
  #   </div>
  #
  #   <%# app/views/users/_editor.html.erb %>
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
  # If a collection is given, the layout will be rendered once for each item in
  # the collection. For example, these two snippets have the same output:
  #
  #   <%# app/views/users/_user.html.erb %>
  #   Name: <%= user.name %>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <%# This does not use layouts %>
  #   <ul>
  #     <% users.each do |user| -%>
  #       <li>
  #         <%= render partial: "user", locals: { user: user } %>
  #       </li>
  #     <% end -%>
  #   </ul>
  #
  #   <%# app/views/users/_li_layout.html.erb %>
  #   <li>
  #     <%= yield %>
  #   </li>
  #
  #   <%# app/views/users/index.html.erb %>
  #   <ul>
  #     <%= render partial: "user", layout: "li_layout", collection: users %>
  #   </ul>
  #
  # Given two users whose names are Alice and Bob, these snippets return:
  #
  #   <ul>
  #     <li>
  #       Name: Alice
  #     </li>
  #     <li>
  #       Name: Bob
  #     </li>
  #   </ul>
  #
  # The current object being rendered, as well as the object_counter, will be
  # available as local variables inside the layout template under the same names
  # as available in the partial.
  #
  # You can also apply a layout to a block within any template:
  #
  #   <%# app/views/users/_chief.html.erb %>
  #   <%= render(layout: "administrator", locals: { user: chief }) do %>
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
  class PartialRenderer < AbstractRenderer
    include CollectionCaching

    def initialize(lookup_context, options)
      super(lookup_context)
      @options = options
      @locals  = @options[:locals] || {}
      @details = extract_details(@options)
    end

    def render(partial, context, block)
      template = find_template(partial, template_keys(partial))

      if !block && (layout = @options[:layout])
        layout = find_template(layout.to_s, template_keys(partial))
      end

      render_partial_template(context, @locals, template, layout, block)
    end

    private
      def template_keys(_)
        @locals.keys
      end

      def render_partial_template(view, locals, template, layout, block)
        ActiveSupport::Notifications.instrument(
          "render_partial.action_view",
          identifier: template.identifier,
          layout: layout && layout.virtual_path
        ) do |payload|
          content = template.render(view, locals, add_to_stack: !block) do |*name|
            view._layout_for(*name, &block)
          end

          content = layout.render(view, locals) { content } if layout
          payload[:cache_hit] = view.view_renderer.cache_hits[template.virtual_path]
          build_rendered_template(content, template)
        end
      end

      def find_template(path, locals)
        prefixes = path.include?(?/) ? [] : @lookup_context.prefixes
        @lookup_context.find_template(path, prefixes, true, locals, @details)
      end
  end
end

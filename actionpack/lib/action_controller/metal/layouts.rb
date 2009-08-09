module ActionController
  # Layouts reverse the common pattern of including shared headers and footers in many templates to isolate changes in
  # repeated setups. The inclusion pattern has pages that look like this:
  #
  #   <%= render "shared/header" %>
  #   Hello World
  #   <%= render "shared/footer" %>
  #
  # This approach is a decent way of keeping common structures isolated from the changing content, but it's verbose
  # and if you ever want to change the structure of these two includes, you'll have to change all the templates.
  #
  # With layouts, you can flip it around and have the common structure know where to insert changing content. This means
  # that the header and footer are only mentioned in one place, like this:
  #
  #   // The header part of this layout
  #   <%= yield %>
  #   // The footer part of this layout
  #
  # And then you have content pages that look like this:
  #
  #    hello world
  #
  # At rendering time, the content page is computed and then inserted in the layout, like this:
  #
  #   // The header part of this layout
  #   hello world
  #   // The footer part of this layout
  #
  # == Accessing shared variables
  #
  # Layouts have access to variables specified in the content pages and vice versa. This allows you to have layouts with
  # references that won't materialize before rendering time:
  #
  #   <h1><%= @page_title %></h1>
  #   <%= yield %>
  #
  # ...and content pages that fulfill these references _at_ rendering time:
  #
  #    <% @page_title = "Welcome" %>
  #    Off-world colonies offers you a chance to start a new life
  #
  # The result after rendering is:
  #
  #   <h1>Welcome</h1>
  #   Off-world colonies offers you a chance to start a new life
  #
  # == Layout assignment
  #
  # You can either specify a layout declaratively (using the #layout class method) or give
  # it the same name as your controller, and place it in <tt>app/views/layouts</tt>.
  # If a subclass does not have a layout specified, it inherits its layout using normal Ruby inheritance.
  #
  # For instance, if you have PostsController and a template named <tt>app/views/layouts/posts.html.erb</tt>,
  # that template will be used for all actions in PostsController and controllers inheriting
  # from PostsController.
  #
  # If you use a module, for instance Weblog::PostsController, you will need a template named
  # <tt>app/views/layouts/weblog/posts.html.erb</tt>.
  #
  # Since all your controllers inherit from ApplicationController, they will use
  # <tt>app/views/layouts/application.html.erb</tt> if no other layout is specified
  # or provided.
  #
  # == Inheritance Examples
  #
  #   class BankController < ActionController::Base
  #     layout "bank_standard"
  #
  #   class InformationController < BankController
  #
  #   class TellerController < BankController
  #     # teller.html.erb exists
  #
  #   class TillController < TellerController
  #
  #   class VaultController < BankController
  #     layout :access_level_layout
  #
  #   class EmployeeController < BankController
  #     layout nil
  #
  # The InformationController uses "bank_standard" inherited from the BankController, the VaultController overwrites
  # and picks the layout dynamically, and the EmployeeController doesn't want to use a layout at all.
  #
  # The TellerController uses +teller.html.erb+, and TillController inherits that layout and
  # uses it as well.
  #
  # == Types of layouts
  #
  # Layouts are basically just regular templates, but the name of this template needs not be specified statically. Sometimes
  # you want to alternate layouts depending on runtime information, such as whether someone is logged in or not. This can
  # be done either by specifying a method reference as a symbol or using an inline method (as a proc).
  #
  # The method reference is the preferred approach to variable layouts and is used like this:
  #
  #   class WeblogController < ActionController::Base
  #     layout :writers_and_readers
  #
  #     def index
  #       # fetching posts
  #     end
  #
  #     private
  #       def writers_and_readers
  #         logged_in? ? "writer_layout" : "reader_layout"
  #       end
  #
  # Now when a new request for the index action is processed, the layout will vary depending on whether the person accessing
  # is logged in or not.
  #
  # If you want to use an inline method, such as a proc, do something like this:
  #
  #   class WeblogController < ActionController::Base
  #     layout proc{ |controller| controller.logged_in? ? "writer_layout" : "reader_layout" }
  #
  # Of course, the most common way of specifying a layout is still just as a plain template name:
  #
  #   class WeblogController < ActionController::Base
  #     layout "weblog_standard"
  #
  # If no directory is specified for the template name, the template will by default be looked for in <tt>app/views/layouts/</tt>.
  # Otherwise, it will be looked up relative to the template root.
  #
  # == Conditional layouts
  #
  # If you have a layout that by default is applied to all the actions of a controller, you still have the option of rendering
  # a given action or set of actions without a layout, or restricting a layout to only a single action or a set of actions. The
  # <tt>:only</tt> and <tt>:except</tt> options can be passed to the layout call. For example:
  #
  #   class WeblogController < ActionController::Base
  #     layout "weblog_standard", :except => :rss
  #
  #     # ...
  #
  #   end
  #
  # This will assign "weblog_standard" as the WeblogController's layout  except for the +rss+ action, which will not wrap a layout
  # around the rendered view.
  #
  # Both the <tt>:only</tt> and <tt>:except</tt> condition can accept an arbitrary number of method references, so
  # #<tt>:except => [ :rss, :text_only ]</tt> is valid, as is <tt>:except => :rss</tt>.
  #
  # == Using a different layout in the action render call
  #
  # If most of your actions use the same layout, it makes perfect sense to define a controller-wide layout as described above.
  # Sometimes you'll have exceptions where one action wants to use a different layout than the rest of the controller.
  # You can do this by passing a <tt>:layout</tt> option to the <tt>render</tt> call. For example:
  #
  #   class WeblogController < ActionController::Base
  #     layout "weblog_standard"
  #
  #     def help
  #       render :action => "help", :layout => "help"
  #     end
  #   end
  #
  # This will render the help action with the "help" layout instead of the controller-wide "weblog_standard" layout.
  module Layouts
    extend ActiveSupport::Concern

    include ActionController::RenderingController
    include AbstractController::Layouts

    module ClassMethods
      # If no layout is provided, look for a layout with this name.
      def _implied_layout_name
        controller_path
      end
    end

    private
      def _determine_template(options)
        super

        return if (options.key?(:text) || options.key?(:inline) || options.key?(:partial)) && !options.key?(:layout)
        layout = options.key?(:layout) ? options[:layout] : :default
        options[:_layout] = _layout_for_option(layout, options[:_template].details)
      end

      def _layout_for_option(name, details)
        case name
        when String     then _layout_for_name(name, details)
        when true       then _default_layout(details, true)
        when :default   then _default_layout(details, false)
        when false, nil then nil
        else
          raise ArgumentError,
            "String, true, or false, expected for `layout'; you passed #{name.inspect}"
        end
      end
  end
end

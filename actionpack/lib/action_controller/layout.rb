module ActionController #:nodoc:
  module Layout #:nodoc:
    def self.append_features(base)
      super
      base.extend(ClassMethods)
      base.class_eval do
        alias_method :render_without_layout, :render
        alias_method :render, :render_with_layout
      end
    end

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
    # that the header and footer is only mentioned in one place, like this:
    #
    #   <!-- The header part of this layout -->
    #   <%= @content_for_layout %>
    #   <!-- The footer part of this layout -->
    #
    # And then you have content pages that look like this:
    #
    #    hello world
    #
    # Not a word about common structures. At rendering time, the content page is computed and then inserted in the layout, 
    # like this:
    #
    #   <!-- The header part of this layout -->
    #   hello world
    #   <!-- The footer part of this layout -->
    #
    # == Accessing shared variables
    #
    # Layouts have access to variables specified in the content pages and vice versa. This allows you to have layouts with
    # references that won't materialize before rendering time:
    #
    #   <h1><%= @page_title %></h1>
    #   <%= @content_for_layout %>
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
    # == Inheritance for layouts
    #
    # Layouts are shared downwards in the inheritance hierarchy, but not upwards. Examples:
    #
    #   class BankController < ActionController::Base
    #     layout "layouts/bank_standard"
    #
    #   class InformationController < BankController
    #
    #   class VaultController < BankController
    #     layout :access_level_layout
    #
    #   class EmployeeController < BankController
    #     layout nil
    #
    # The InformationController uses "layouts/bank_standard" inherited from the BankController, the VaultController overwrites
    # and picks the layout dynamically, and the EmployeeController doesn't want to use a layout at all.
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
    # Of course, the most common way of specifying a layout is still just as a plain template path:
    #
    #   class WeblogController < ActionController::Base
    #     layout "layouts/weblog_standard"
    #
    # == Avoiding the use of a layout
    #
    # If you have a layout that by default is applied to all the actions of a controller, you still have the option to rendering
    # a given action without a layout. Just use the method <tt>render_without_layout</tt>, which works just like Base.render --
    # it just doesn't apply any layouts.
    module ClassMethods
      # If a layout is specified, all actions rendered through render and render_action will have their result assigned 
      # to <tt>@content_for_layout</tt>, which can then be used by the layout to insert their contents with
      # <tt><%= @content_for_layout %></tt>. This layout can itself depend on instance variables assigned during action
      # performance and have access to them as any normal template would.
      def layout(template_name)
        write_inheritable_attribute "layout", template_name
      end
    end

    # Returns the name of the active layout. If the layout was specified as a method reference (through a symbol), this method
    # is called and the return value is used. Likewise if the layout was specified as an inline method (through a proc or method
    # object). If the layout was defined without a directory, layouts is assumed. So <tt>layout "weblog/standard"</tt> will return
    # weblog/standard, but <tt>layout "standard"</tt> will return layouts/standard.
    def active_layout(passed_layout = nil)
      layout = passed_layout || self.class.read_inheritable_attribute("layout")
      active_layout = case layout
        when Symbol then send(layout)
        when Proc   then layout.call(self)
        when String then layout
      end
      active_layout.include?("/") ? active_layout : "layouts/#{active_layout}" if active_layout
    end

    def render_with_layout(template_name = default_template_name, status = nil, layout = nil) #:nodoc:
      if layout ||= active_layout
        add_variables_to_assigns
        logger.info("Rendering #{template_name} within #{layout}") unless logger.nil?
        @content_for_layout = @template.render_file(template_name, true)
        render_without_layout(layout, status)
      else
        render_without_layout(template_name, status)
      end
    end
  end
end

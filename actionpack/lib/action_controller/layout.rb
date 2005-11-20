module ActionController #:nodoc:
  module Layout #:nodoc:
    def self.append_features(base)
      super
      base.class_eval do
        alias_method :render_with_no_layout, :render
        alias_method :render, :render_with_a_layout

        class << self
          alias_method :inherited_without_layout, :inherited
        end
      end
      base.extend(ClassMethods)
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
    # that the header and footer are only mentioned in one place, like this:
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
    # == Automatic layout assignment
    #
    # If there is a template in <tt>app/views/layouts/</tt> with the same name as the current controller then it will be automatically
    # set as that controller's layout unless explicitly told otherwise. Say you have a WeblogController, for example. If a template named 
    # <tt>app/views/layouts/weblog.rhtml</tt> or <tt>app/views/layouts/weblog.rxml</tt> exists then it will be automatically set as
    # the layout for your WeblogController. You can create a layout with the name <tt>application.rhtml</tt> or <tt>application.rxml</tt>
    # and this will be set as the default controller if there is no layout with the same name as the current controller and there is 
    # no layout explicitly assigned with the +layout+ method. Setting a layout explicitly will always override the automatic behaviour
    # for the controller where the layout is set. Explicitly setting the layout in a parent class, though, will not override the 
    # child class's layout assignement if the child class has a layout with the same name. 
    #
    # == Inheritance for layouts
    #
    # Layouts are shared downwards in the inheritance hierarchy, but not upwards. Examples:
    #
    #   class BankController < ActionController::Base
    #     layout "bank_standard"
    #
    #   class InformationController < BankController
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
    # If no directory is specified for the template name, the template will by default by looked for in +app/views/layouts/+.
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
    # Some times you'll have exceptions, though, where one action wants to use a different layout than the rest of the controller.
    # This is possible using the <tt>render</tt> method. It's just a bit more manual work as you'll have to supply fully
    # qualified template and layout names as this example shows:
    #
    #   class WeblogController < ActionController::Base
    #     def help
    #       render :action => "help/index", :layout => "help"
    #     end
    #   end
    #
    # As you can see, you pass the template as the first parameter, the status code as the second ("200" is OK), and the layout
    # as the third.
    module ClassMethods
      # If a layout is specified, all actions rendered through render and render_action will have their result assigned 
      # to <tt>@content_for_layout</tt>, which can then be used by the layout to insert their contents with
      # <tt><%= @content_for_layout %></tt>. This layout can itself depend on instance variables assigned during action
      # performance and have access to them as any normal template would.
      def layout(template_name, conditions = {})
        add_layout_conditions(conditions)
        write_inheritable_attribute "layout", template_name
      end

      def layout_conditions #:nodoc:
        read_inheritable_attribute("layout_conditions")
      end

      private
        def inherited(child)
          inherited_without_layout(child)
          child.layout(child.controller_name) unless layout_list.grep(/^#{child.controller_name}\.r(?:x|ht)ml$/).empty?
        end

        def layout_list
          Dir.glob("#{template_root}/layouts/*.r{x,ht}ml").map { |layout| File.basename(layout) }
        end

        def add_layout_conditions(conditions)
          write_inheritable_hash "layout_conditions", normalize_conditions(conditions)
        end

        def normalize_conditions(conditions)
          conditions.inject({}) {|hash, (key, value)| hash.merge(key => [value].flatten.map {|action| action.to_s})}
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

    def render_with_a_layout(options = nil, deprecated_status = nil, deprecated_layout = nil) #:nodoc:
      template_with_options = options.is_a?(Hash)

      if apply_layout?(template_with_options, options) && (layout = pick_layout(template_with_options, options, deprecated_layout))
        options = options.merge :layout => false if template_with_options
        logger.info("Rendering #{options} within #{layout}") if logger

        if template_with_options
          content_for_layout = render_with_no_layout(options)
          deprecated_status = options[:status] || deprecated_status
        else
          content_for_layout = render_with_no_layout(options, deprecated_status)
        end

        erase_render_results
        add_variables_to_assigns
        @template.instance_variable_set("@content_for_layout", content_for_layout)
        render_text(@template.render_file(layout, true), deprecated_status)
      else
        render_with_no_layout(options, deprecated_status)
      end
    end

    private
      def apply_layout?(template_with_options, options)
        if template_with_options
          (options.has_key?(:layout) && options[:layout]!=false) || options.values_at(:text, :file, :inline, :partial, :nothing).compact.empty?
        else
          true
        end
      end

      def pick_layout(template_with_options, options, deprecated_layout)
        if deprecated_layout
          deprecated_layout
        elsif template_with_options
          case layout = options[:layout]
            when FalseClass
              nil
            when NilClass, TrueClass
              active_layout if action_has_layout?
            else
              active_layout(layout)
          end
        else
          active_layout if action_has_layout?
        end
      end

      def action_has_layout?
        if conditions = self.class.layout_conditions
          case
            when only = conditions[:only]
              only.include?(action_name)
            when except = conditions[:except]
              !except.include?(action_name) 
            else
              true
          end
        else
          true
        end
      end
  end
end

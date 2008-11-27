module ActionController #:nodoc:
  module Layout #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        class << self
          alias_method_chain :inherited, :layout
        end
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
    # NOTE: The old notation for rendering the view from a layout was to expose the magic <tt>@content_for_layout</tt> instance
    # variable. The preferred notation now is to use <tt>yield</tt>, as documented above.
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
    # == Automatic layout assignment
    #
    # If there is a template in <tt>app/views/layouts/</tt> with the same name as the current controller then it will be automatically
    # set as that controller's layout unless explicitly told otherwise. Say you have a WeblogController, for example. If a template named
    # <tt>app/views/layouts/weblog.erb</tt> or <tt>app/views/layouts/weblog.builder</tt> exists then it will be automatically set as
    # the layout for your WeblogController. You can create a layout with the name <tt>application.erb</tt> or <tt>application.builder</tt>
    # and this will be set as the default controller if there is no layout with the same name as the current controller and there is
    # no layout explicitly assigned with the +layout+ method. Nested controllers use the same folder structure for automatic layout.
    # assignment. So an Admin::WeblogController will look for a template named <tt>app/views/layouts/admin/weblog.erb</tt>.
    # Setting a layout explicitly will always override the automatic behaviour for the controller where the layout is set.
    # Explicitly setting the layout in a parent class, though, will not override the child class's layout assignment if the child
    # class has a layout with the same name.
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
    module ClassMethods
      # If a layout is specified, all rendered actions will have their result rendered
      # when the layout <tt>yield</tt>s. This layout can itself depend on instance variables assigned during action
      # performance and have access to them as any normal template would.
      def layout(template_name, conditions = {}, auto = false)
        add_layout_conditions(conditions)
        write_inheritable_attribute(:layout, template_name)
        write_inheritable_attribute(:auto_layout, auto)
      end

      def layout_conditions #:nodoc:
        @layout_conditions ||= read_inheritable_attribute(:layout_conditions)
      end

      def default_layout(format) #:nodoc:
        layout = read_inheritable_attribute(:layout)
        return layout unless read_inheritable_attribute(:auto_layout)
        @default_layout ||= {}
        @default_layout[format] ||= default_layout_with_format(format, layout)
        @default_layout[format]
      end

      def layout_list #:nodoc:
        Array(view_paths).sum([]) { |path| Dir["#{path}/layouts/**/*"] }
      end

      private
        def inherited_with_layout(child)
          inherited_without_layout(child)
          unless child.name.blank?
            layout_match = child.name.underscore.sub(/_controller$/, '').sub(/^controllers\//, '')
            child.layout(layout_match, {}, true) unless child.layout_list.grep(%r{layouts/#{layout_match}(\.[a-z][0-9a-z]*)+$}).empty?
          end
        end

        def add_layout_conditions(conditions)
          write_inheritable_hash(:layout_conditions, normalize_conditions(conditions))
        end

        def normalize_conditions(conditions)
          conditions.inject({}) {|hash, (key, value)| hash.merge(key => [value].flatten.map {|action| action.to_s})}
        end

        def default_layout_with_format(format, layout)
          list = layout_list
          if list.grep(%r{layouts/#{layout}\.#{format}(\.[a-z][0-9a-z]*)+$}).empty?
            (!list.grep(%r{layouts/#{layout}\.([a-z][0-9a-z]*)+$}).empty? && format == :html) ? layout : nil
          else
            layout
          end
        end
    end

    # Returns the name of the active layout. If the layout was specified as a method reference (through a symbol), this method
    # is called and the return value is used. Likewise if the layout was specified as an inline method (through a proc or method
    # object). If the layout was defined without a directory, layouts is assumed. So <tt>layout "weblog/standard"</tt> will return
    # weblog/standard, but <tt>layout "standard"</tt> will return layouts/standard.
    def active_layout(passed_layout = nil)
      layout = passed_layout || self.class.default_layout(default_template_format)
      active_layout = case layout
        when String then layout
        when Symbol then __send__(layout)
        when Proc   then layout.call(self)
      end

      # Explicitly passed layout names with slashes are looked up relative to the template root,
      # but auto-discovered layouts derived from a nested controller will contain a slash, though be relative
      # to the 'layouts' directory so we have to check the file system to infer which case the layout name came from.
      if active_layout
        if active_layout.include?('/') && ! layout_directory?(active_layout)
          active_layout
        else
          "layouts/#{active_layout}"
        end
      end
    end

    private
      def candidate_for_layout?(options)
        options.values_at(:text, :xml, :json, :file, :inline, :partial, :nothing, :update).compact.empty? &&
          !@template.__send__(:_exempt_from_layout?, options[:template] || default_template_name(options[:action]))
      end

      def pick_layout(options)
        if options.has_key?(:layout)
          case layout = options.delete(:layout)
          when FalseClass
            nil
          when NilClass, TrueClass
            active_layout if action_has_layout? && !@template.__send__(:_exempt_from_layout?, default_template_name)
          else
            active_layout(layout)
          end
        else
          active_layout if action_has_layout? && candidate_for_layout?(options)
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

      def layout_directory?(layout_name)
        @template.__send__(:_pick_template, "#{File.join('layouts', layout_name)}.#{@template.template_format}") ? true : false
      rescue ActionView::MissingTemplate
        false
      end

      def default_template_format
        response.template.template_format
      end
  end
end

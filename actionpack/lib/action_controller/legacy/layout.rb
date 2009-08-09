require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/class'
require 'active_support/core_ext/class/delegating_attributes'
require 'active_support/core_ext/class/inheritable_attributes'

module ActionController #:nodoc:
  # MegasuperultraHAX
  # plz refactor ActionMailer
  class Base
    @@exempt_from_layout = [ActionView::TemplateHandlers::RJS]
    cattr_accessor :exempt_from_layout
  end

  module Layout #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)
      base.class_inheritable_accessor :layout_name, :layout_conditions
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
      extend ActiveSupport::Memoizable

      # If a layout is specified, all rendered actions will have their result rendered
      # when the layout <tt>yield</tt>s. This layout can itself depend on instance variables assigned during action
      # performance and have access to them as any normal template would.
      def layout(template_name, conditions = {}, auto = false)
        add_layout_conditions(conditions)
        self.layout_name = template_name
      end

      def memoized_default_layout(formats) #:nodoc:
        self.layout_name || begin
          layout = default_layout_name
          layout.is_a?(String) ? find_layout(layout, formats) : layout
        rescue ActionView::MissingTemplate
        end
      end

      def default_layout(*args)
        memoized_default_layout(*args)
        @_memoized_default_layout ||= ::ActiveSupport::ConcurrentHash.new
        @_memoized_default_layout[args] ||= memoized_default_layout(*args)
      end

      def memoized_find_layout(layout, formats) #:nodoc:
        return layout if layout.nil? || layout.respond_to?(:render)
        prefix = layout.to_s =~ /layouts\// ? nil : "layouts"
        view_paths.find(layout.to_s, {:formats => formats}, prefix)
      end

      def find_layout(*args)
        @_memoized_find_layout ||= ::ActiveSupport::ConcurrentHash.new
        @_memoized_find_layout[args] ||= memoized_find_layout(*args)
      end

      def layout_list #:nodoc:
        Array(view_paths).sum([]) { |path| Dir["#{path.to_str}/layouts/**/*"] }
      end
      memoize :layout_list

      def default_layout_name
        layout_match = name.underscore.sub(/_controller$/, '')
        if layout_list.grep(%r{layouts/#{layout_match}(\.[a-z][0-9a-z]*)+$}).empty?
          superclass.default_layout_name if superclass.respond_to?(:default_layout_name)
        else
          layout_match
        end
      end
      memoize :default_layout_name

      private
        def add_layout_conditions(conditions)
          # :except => :foo == :except => [:foo] == :except => "foo" == :except => ["foo"]
          conditions.each {|k, v| conditions[k] = Array(v).map {|a| a.to_s} }
          write_inheritable_hash(:layout_conditions, conditions)
        end
    end
    
    def active_layout(name)
      name = self.class.default_layout(formats) if name == true
      
      layout_name = case name
        when Symbol     then __send__(name)
        when Proc       then name.call(self)
        else name
      end

      self.class.find_layout(layout_name, formats)
    end

    def _pick_layout(layout_name = nil, implicit = false)
      return unless layout_name || implicit
      layout_name = true if layout_name.nil?
      active_layout(layout_name) if action_has_layout? && layout_name
    end

    private
      def action_has_layout?
        if conditions = self.class.layout_conditions
          if only = conditions[:only]
            return only.include?(action_name)
          elsif except = conditions[:except]
            return !except.include?(action_name) 
          end
        end
        true
      end

  end
end

require "active_support/core_ext/module/remove_method"

module AbstractController
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
  # In these examples:
  # * The InformationController uses the "bank_standard" layout, inherited from BankController.
  # * The TellerController follows convention and uses +app/views/layouts/teller.html.erb+.
  # * The TillController inherits the layout from TellerController and uses +teller.html.erb+ as well.
  # * The VaultController chooses a layout dynamically by calling the <tt>access_level_layout</tt> method.
  # * The EmployeeController does not use a layout at all.
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
  #   end
  #
  # Of course, the most common way of specifying a layout is still just as a plain template name:
  #
  #   class WeblogController < ActionController::Base
  #     layout "weblog_standard"
  #   end
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
  # This will assign "weblog_standard" as the WeblogController's layout for all actions except for the +rss+ action, which will
  # be rendered directly, without wrapping a layout around the rendered view.
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
  # This will override the controller-wide "weblog_standard" layout, and will render the help action with the "help" layout instead.
  module Layouts
    extend ActiveSupport::Concern

    include Rendering

    included do
      class_attribute :_layout_conditions
      remove_possible_method :_layout_conditions
      delegate :_layout_conditions, :to => :'self.class'
      self._layout_conditions = {}
      _write_layout_method
    end

    module ClassMethods
      def inherited(klass)
        super
        klass._write_layout_method
      end

      # This module is mixed in if layout conditions are provided. This means
      # that if no layout conditions are used, this method is not used
      module LayoutConditions
        # Determines whether the current action has a layout by checking the
        # action name against the :only and :except conditions set on the
        # layout.
        #
        # ==== Returns
        # * <tt> Boolean</tt> - True if the action has a layout, false otherwise.
        def action_has_layout?
          return unless super

          conditions = _layout_conditions

          if only = conditions[:only]
            only.include?(action_name)
          elsif except = conditions[:except]
            !except.include?(action_name)
          else
            true
          end
        end
      end

      # Specify the layout to use for this class.
      #
      # If the specified layout is a:
      # String:: the String is the template name
      # Symbol:: call the method specified by the symbol, which will return
      #   the template name
      # false::  There is no layout
      # true::   raise an ArgumentError
      #
      # ==== Parameters
      # * <tt>String, Symbol, false</tt> - The layout to use.
      #
      # ==== Options (conditions)
      # * :only   - A list of actions to apply this layout to.
      # * :except - Apply this layout to all actions but this one.
      def layout(layout, conditions = {})
        include LayoutConditions unless conditions.empty?

        conditions.each {|k, v| conditions[k] = Array(v).map {|a| a.to_s} }
        self._layout_conditions = conditions

        @_layout = layout || false # Converts nil to false
        _write_layout_method
      end

      # If no layout is supplied, look for a template named the return
      # value of this method.
      #
      # ==== Returns
      # * <tt>String</tt> - A template name
      def _implied_layout_name
        controller_path
      end

      # Creates a _layout method to be called by _default_layout .
      #
      # If a layout is not explicitly mentioned then look for a layout with the controller's name.
      # if nothing is found then try same procedure to find super class's layout.
      def _write_layout_method
        remove_possible_method(:_layout)

        case defined?(@_layout) ? @_layout : nil
        when String
          self.class_eval %{def _layout; #{@_layout.inspect} end}, __FILE__, __LINE__
        when Symbol
          self.class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def _layout
              #{@_layout}.tap do |layout|
                unless layout.is_a?(String) || !layout
                  raise ArgumentError, "Your layout method :#{@_layout} returned \#{layout}. It " \
                    "should have returned a String, false, or nil"
                end
              end
            end
          ruby_eval
        when Proc
          define_method :_layout_from_proc, &@_layout
          self.class_eval %{def _layout; _layout_from_proc(self) end}, __FILE__, __LINE__
        when false
          self.class_eval %{def _layout; end}, __FILE__, __LINE__
        when true
          raise ArgumentError, "Layouts must be specified as a String, Symbol, false, or nil"
        when nil
          if name
            _prefixes = _implied_layout_name =~ /\blayouts/ ? [] : ["layouts"]

            self.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def _layout
                if template_exists?("#{_implied_layout_name}", #{_prefixes.inspect})
                  "#{_implied_layout_name}"
                else
                  super
                end
              end
            RUBY
          end
        end
        self.class_eval { private :_layout }
      end
    end

    def _normalize_options(options)
      super

      if _include_layout?(options)
        layout = options.key?(:layout) ? options.delete(:layout) : :default
        value = _layout_for_option(layout)
        options[:layout] = (value =~ /\blayouts/ ? value : "layouts/#{value}") if value
      end
    end

    attr_internal_writer :action_has_layout

    def initialize(*)
      @_action_has_layout = true
      super
    end

    def action_has_layout?
      @_action_has_layout
    end

  private

    # This will be overwritten by _write_layout_method
    def _layout; end

    # Determine the layout for a given name and details, taking into account
    # the name type.
    #
    # ==== Parameters
    # * <tt>name</tt> - The name of the template
    # * <tt>details</tt> - A list of details to restrict
    #   the lookup to. By default, layout lookup is limited to the
    #   formats specified for the current request.
    def _layout_for_option(name)
      case name
      when String     then name
      when true       then _default_layout(true)
      when :default   then _default_layout(false)
      when false, nil then nil
      else
        raise ArgumentError,
          "String, true, or false, expected for `layout'; you passed #{name.inspect}"
      end
    end

    # Returns the default layout for this controller and a given set of details.
    # Optionally raises an exception if the layout could not be found.
    #
    # ==== Parameters
    # * <tt>details</tt> - A list of details to restrict the search by. This
    #   might include details like the format or locale of the template.
    # * <tt>require_layout</tt> - If this is true, raise an ArgumentError
    #   with details about the fact that the exception could not be
    #   found (defaults to false)
    #
    # ==== Returns
    # * <tt>template</tt> - The template object for the default layout (or nil)
    def _default_layout(require_layout = false)
      begin
        layout_name = _layout if action_has_layout?
      rescue NameError => e
        raise e, "Could not render layout: #{e.message}"
      end

      if require_layout && action_has_layout? && !layout_name
        raise ArgumentError,
          "There was no default layout for #{self.class} in #{view_paths.inspect}"
      end

      layout_name
    end

    def _include_layout?(options)
      (options.keys & [:text, :inline, :partial]).empty? || options.key?(:layout)
    end
  end
end

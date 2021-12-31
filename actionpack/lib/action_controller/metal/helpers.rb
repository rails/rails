# frozen_string_literal: true

module ActionController
  # The \Rails framework provides a large number of helpers for working with assets, dates, forms,
  # numbers and model objects, to name a few. These helpers are available to all templates
  # by default.
  #
  # In addition to using the standard template helpers provided, creating custom helpers to
  # extract complicated logic or reusable functionality is strongly encouraged. By default, each controller
  # will include all helpers. These helpers are only accessible on the controller through <tt>#helpers</tt>
  #
  # In previous versions of \Rails the controller will include a helper which
  # matches the name of the controller, e.g., <tt>MyController</tt> will automatically
  # include <tt>MyHelper</tt>. You can revert to the old behavior with the following:
  #
  #    # config/application.rb
  #    class Application < Rails::Application
  #      config.action_controller.include_all_helpers = false
  #    end
  #
  # Additional helpers can be specified using the +helper+ class method in ActionController::Base or any
  # controller which inherits from it.
  #
  # The +to_s+ method from the \Time class can be wrapped in a helper method to display a custom message if
  # a \Time object is blank:
  #
  #   module FormattedTimeHelper
  #     def format_time(time, format=:long, blank_message="&nbsp;")
  #       time.blank? ? blank_message : time.to_formatted_s(format)
  #     end
  #   end
  #
  # FormattedTimeHelper can now be included in a controller, using the +helper+ class method:
  #
  #   class EventsController < ActionController::Base
  #     helper FormattedTimeHelper
  #     def index
  #       @events = Event.all
  #     end
  #   end
  #
  # Then, in any view rendered by <tt>EventsController</tt>, the <tt>format_time</tt> method can be called:
  #
  #   <% @events.each do |event| -%>
  #     <p>
  #       <%= format_time(event.time, :short, "N/A") %> | <%= event.name %>
  #     </p>
  #   <% end -%>
  #
  # Finally, assuming we have two event instances, one which has a time and one which does not,
  # the output might look like this:
  #
  #   23 Aug 11:30 | Carolina Railhawks Soccer Match
  #   N/A | Carolina Railhawks Training Workshop
  #
  module Helpers
    extend ActiveSupport::Concern

    class << self; attr_accessor :helpers_path; end
    include AbstractController::Helpers

    included do
      class_attribute :helpers_path, default: []
      class_attribute :include_all_helpers, default: true
    end

    module ClassMethods
      # Declares helper accessors for controller attributes. For example, the
      # following adds new +name+ and <tt>name=</tt> instance methods to a
      # controller and makes them available to the view:
      #   attr_accessor :name
      #   helper_attr :name
      #
      # ==== Parameters
      # * <tt>attrs</tt> - Names of attributes to be converted into helpers.
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end

      # Provides a proxy to access helper methods from outside the view.
      #
      # Note that the proxy is rendered under a different view context.
      # This may cause incorrect behaviour with capture methods. Consider
      # using {helper}[rdoc-ref:AbstractController::Helpers::ClassMethods#helper]
      # instead when using +capture+.
      def helpers
        @helper_proxy ||= begin
          proxy = ActionView::Base.empty
          proxy.config = config.inheritable_copy
          proxy.extend(_helpers)
        end
      end

      # Overwrite modules_for_helpers to accept :all as argument, which loads
      # all helpers in helpers_path.
      #
      # ==== Parameters
      # * <tt>args</tt> - A list of helpers
      #
      # ==== Returns
      # * <tt>array</tt> - A normalized list of modules for the list of helpers provided.
      def modules_for_helpers(args)
        args += all_application_helpers if args.delete(:all)
        super(args)
      end

      # Returns a list of helper names in a given path.
      #
      #   ActionController::Base.all_helpers_from_path 'app/helpers'
      #   # => ["application", "chart", "rubygems"]
      def all_helpers_from_path(path)
        helpers = Array(path).flat_map do |_path|
          names = Dir["#{_path}/**/*_helper.rb"].map { |file| file[_path.to_s.size + 1..-"_helper.rb".size - 1] }
          names.sort!
        end
        helpers.uniq!
        helpers
      end

      private
        # Extract helper names from files in <tt>app/helpers/**/*_helper.rb</tt>
        def all_application_helpers
          all_helpers_from_path(helpers_path)
        end
    end

    # Provides a proxy to access helper methods from outside the view.
    def helpers
      @_helper_proxy ||= view_context
    end
  end
end

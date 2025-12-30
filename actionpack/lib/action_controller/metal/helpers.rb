# frozen_string_literal: true

# :markup: markdown

module ActionController
  # # Action Controller Helpers
  #
  # The Rails framework provides a large number of helpers for working with
  # assets, dates, forms, numbers and model objects, to name a few. These helpers
  # are available to all templates by default.
  #
  # In addition to using the standard template helpers provided, creating custom
  # helpers to extract complicated logic or reusable functionality is strongly
  # encouraged. By default, each controller will include all helpers. These
  # helpers are only accessible on the controller through `#helpers`
  #
  # In previous versions of Rails the controller will include a helper which
  # matches the name of the controller, e.g., `MyController` will automatically
  # include `MyHelper`. You can revert to the old behavior with the following:
  #
  #     # config/application.rb
  #     class Application < Rails::Application
  #       config.action_controller.include_all_helpers = false
  #     end
  #
  # Additional helpers can be specified using the `helper` class method in
  # ActionController::Base or any controller which inherits from it.
  #
  # The `to_s` method from the Time class can be wrapped in a helper method to
  # display a custom message if a Time object is blank:
  #
  #     module FormattedTimeHelper
  #       def format_time(time, format=:long, blank_message="&nbsp;")
  #         time.blank? ? blank_message : time.to_fs(format)
  #       end
  #     end
  #
  # FormattedTimeHelper can now be included in a controller, using the `helper`
  # class method:
  #
  #     class EventsController < ActionController::Base
  #       helper FormattedTimeHelper
  #       def index
  #         @events = Event.all
  #       end
  #     end
  #
  # Then, in any view rendered by `EventsController`, the `format_time` method can
  # be called:
  #
  #     <% @events.each do |event| -%>
  #       <p>
  #         <%= format_time(event.time, :short, "N/A") %> | <%= event.name %>
  #       </p>
  #     <% end -%>
  #
  # Finally, assuming we have two event instances, one which has a time and one
  # which does not, the output might look like this:
  #
  #     23 Aug 11:30 | Carolina Railhawks Soccer Match
  #     N/A | Carolina Railhawks Training Workshop
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
      # following adds new `name` and `name=` instance methods to a controller and
      # makes them available to the view:
      #     attr_accessor :name
      #     helper_attr :name
      #
      # #### Parameters
      # *   `attrs` - Names of attributes to be converted into helpers.
      #
      def helper_attr(*attrs)
        attrs.flatten.each { |attr| helper_method(attr, "#{attr}=") }
      end

      # Provides a proxy to access helper methods from outside the view.
      #
      # Note that the proxy is rendered under a different view context. This may cause
      # incorrect behavior with capture methods. Consider using
      # [helper](rdoc-ref:AbstractController::Helpers::ClassMethods#helper) instead
      # when using `capture`.
      def helpers
        @helper_proxy ||= begin
          proxy = ActionView::Base.empty
          proxy.config = config.inheritable_copy
          proxy.extend(_helpers)
        end
      end

      # Override modules_for_helpers to accept `:all` as argument, which loads all
      # helpers in helpers_path.
      #
      # #### Parameters
      # *   `args` - A list of helpers
      #
      #
      # #### Returns
      # *   `array` - A normalized list of modules for the list of helpers provided.
      #
      def modules_for_helpers(args)
        args += all_application_helpers if args.delete(:all)
        super(args)
      end

      private
        # Extract helper names from files in `app/helpers/***/**_helper.rb`
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

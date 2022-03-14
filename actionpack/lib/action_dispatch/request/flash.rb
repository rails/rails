# frozen_string_literal: true

require "action_dispatch/request/flash/request_methods"

module ActionDispatch
  class Request
    # = Action Dispatch \Flash
    #
    # The flash provides a way to pass temporary primitive-types (String, Array, Hash) between actions. Anything you place in the flash will be exposed
    # to the very next action and then cleared out. This is a great way of doing notices and alerts, such as a create
    # action that sets <tt>flash[:notice] = "Post successfully created"</tt> before redirecting to a display action that can
    # then expose the flash to its template. Actually, that exposure is automatically done.
    #
    #   class PostsController < ActionController::Base
    #     def create
    #       # save post
    #       flash[:notice] = "Post successfully created"
    #       redirect_to @post
    #     end
    #
    #     def show
    #       # doesn't need to assign the flash notice to the template, that's done automatically
    #     end
    #   end
    #
    # Then in +show.html.erb+:
    #
    #   <% if flash[:notice] %>
    #     <div class="notice"><%= flash[:notice] %></div>
    #   <% end %>
    #
    # Since the +notice+ and +alert+ keys are a common idiom, convenience accessors are available:
    #
    #   flash.alert = "You must be logged in"
    #   flash.notice = "Post successfully created"
    #
    # This example places a string in the flash. And of course, you can put as many as you like at a time too. If you want to pass
    # non-primitive types, you will have to handle that in your application. Example: To show messages with links, you will have to
    # use sanitize helper.
    #
    # Just remember: They'll be gone by the time the next action has been performed.
    #
    # See docs on the ActionDispatch::Request::Flash::FlashHash class for more details about the flash.
    module Flash
      KEY = "action_dispatch.request.flash_hash"

      extend self

      def use! # :nodoc:
        Request.prepend(Flash::RequestMethods)
      end
    end
  end
end

module ActionController #:nodoc:
  # The flash provides a way to pass temporary objects between actions. Anything you place in the flash will be exposed
  # to the very next action and then cleared out. This is a great way of doing notices and alerts, such as a create action
  # that sets <tt>flash["notice"] = "Succesfully created"</tt> before redirecting to a display action that can then expose 
  # the flash to its template. Actually, that exposure is automatically done. Example:
  #
  #   class WeblogController < ActionController::Base
  #     def create
  #       # save post
  #       flash["notice"] = "Succesfully created post"
  #       redirect_to :action => "display", :params => { "id" => post.id }
  #     end
  #
  #     def display
  #       # doesn't need to assign the flash notice to the template, that's done automatically
  #     end
  #   end
  #
  #   display.rhtml
  #     <% if @flash["notice"] %><div class="notice"><%= @flash["notice"] %></div><% end %>
  #
  # This example just places a string in the flash, but you can put any object in there. And of course, you can put as many
  # as you like at a time too. Just remember: They'll be gone by the time the next action has been performed.
  module Flash
    def self.append_features(base) #:nodoc:
      super
      base.before_filter(:fire_flash)
      base.after_filter(:clear_flash)
    end

    protected
      # Access the contents of the flash. Use <tt>flash["notice"]</tt> to read a notice you put there or 
      # <tt>flash["notice"] = "hello"</tt> to put a new one.
      def flash #:doc:
        if @session["flash"].nil?
          @session["flash"]   = {}
          @session["flashes"] ||= 0
        end
        @session["flash"]
      end    

      # Can be called by any action that would like to keep the current content of the flash around for one more action.
      def keep_flash #:doc:
        @session["flashes"] = 0
      end    

    private
      # Records that the contents of @session["flash"] was flashed to the action
      def fire_flash
        if @session["flash"]
          @session["flashes"] += 1 unless @session["flash"].empty?
          @assigns["flash"] = @session["flash"]
        else
          @assigns["flash"] = {}
        end
      end

      def clear_flash
        if @session["flash"] && (@session["flashes"].nil? || @session["flashes"] >= 1)
          @session["flash"]   = {}
          @session["flashes"] = 0 
        end
      end    
  end
end
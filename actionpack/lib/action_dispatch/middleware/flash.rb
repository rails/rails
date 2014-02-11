require 'active_support/core_ext/hash/keys'

module ActionDispatch
  class Request < Rack::Request
    # Access the contents of the flash. Use <tt>flash["notice"]</tt> to
    # read a notice you put there or <tt>flash["notice"] = "hello"</tt>
    # to put a new one.
    def flash
      @env[Flash::KEY] ||= Flash::FlashHash.from_session_value(session["flash"])
    end
  end

  # The flash provides a way to pass temporary objects between actions. Anything you place in the flash will be exposed
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
  #   show.html.erb
  #     <% if flash[:notice] %>
  #       <div class="notice"><%= flash[:notice] %></div>
  #     <% end %>
  #
  # Since the +notice+ and +alert+ keys are a common idiom, convenience accessors are available:
  #
  #   flash.alert = "You must be logged in"
  #   flash.notice = "Post successfully created"
  #
  # This example just places a string in the flash, but you can put any object in there. And of course, you can put as
  # many as you like at a time too. Just remember: They'll be gone by the time the next action has been performed.
  #
  # See docs on the FlashHash class for more details about the flash.
  class Flash
    KEY = 'action_dispatch.request.flash_hash'.freeze

    class FlashNow #:nodoc:
      attr_accessor :flash

      def initialize(flash)
        @flash = flash
      end

      def []=(k, v)
        k = k.to_s
        @flash[k] = v
        @flash.discard(k)
        v
      end

      def [](k)
        @flash[k.to_s]
      end

      # Convenience accessor for <tt>flash.now[:alert]=</tt>.
      def alert=(message)
        self[:alert] = message
      end

      # Convenience accessor for <tt>flash.now[:notice]=</tt>.
      def notice=(message)
        self[:notice] = message
      end
    end

    class FlashHash
      include Enumerable

      def self.from_session_value(value)
        flash = case value
                when FlashHash # Rails 3.1, 3.2
                  new(value.instance_variable_get(:@flashes), value.instance_variable_get(:@used))
                when Hash # Rails 4.0
                  new(value['flashes'], value['discard'])
                else
                  new
                end

        flash.tap(&:sweep)
      end

      def to_session_value
        return nil if empty?
        {'discard' => @discard.to_a, 'flashes' => @flashes}
      end

      def initialize(flashes = {}, discard = []) #:nodoc:
        @discard = Set.new(stringify_array(discard))
        @flashes = flashes.stringify_keys
        @now     = nil
      end

      def initialize_copy(other)
        if other.now_is_loaded?
          @now = other.now.dup
          @now.flash = self
        end
        super
      end

      def []=(k, v)
        k = k.to_s
        @discard.delete k
        @flashes[k] = v
      end

      def [](k)
        @flashes[k.to_s]
      end

      def update(h) #:nodoc:
        @discard.subtract stringify_array(h.keys)
        @flashes.update h.stringify_keys
        self
      end

      def keys
        @flashes.keys
      end

      def key?(name)
        @flashes.key? name
      end

      def delete(key)
        key = key.to_s
        @discard.delete key
        @flashes.delete key
        self
      end

      def to_hash
        @flashes.dup
      end

      def empty?
        @flashes.empty?
      end

      def clear
        @discard.clear
        @flashes.clear
      end

      def each(&block)
        @flashes.each(&block)
      end

      alias :merge! :update

      def replace(h) #:nodoc:
        @discard.clear
        @flashes.replace h.stringify_keys
        self
      end

      # Sets a flash that will not be available to the next action, only to the current.
      #
      #     flash.now[:message] = "Hello current action"
      #
      # This method enables you to use the flash as a central messaging system in your app.
      # When you need to pass an object to the next action, you use the standard flash assign (<tt>[]=</tt>).
      # When you need to pass an object to the current action, you use <tt>now</tt>, and your object will
      # vanish when the current action is done.
      #
      # Entries set via <tt>now</tt> are accessed the same way as standard entries: <tt>flash['my-key']</tt>.
      #
      # Also, brings two convenience accessors:
      #
      #   flash.now.alert = "Beware now!"
      #   # Equivalent to flash.now[:alert] = "Beware now!"
      #
      #   flash.now.notice = "Good luck now!"
      #   # Equivalent to flash.now[:notice] = "Good luck now!"
      def now
        @now ||= FlashNow.new(self)
      end

      # Keeps either the entire current flash or a specific flash entry available for the next action:
      #
      #    flash.keep            # keeps the entire flash
      #    flash.keep(:notice)   # keeps only the "notice" entry, the rest of the flash is discarded
      def keep(k = nil)
        k = k.to_s if k
        @discard.subtract Array(k || keys)
        k ? self[k] : self
      end

      # Marks the entire flash or a single flash entry to be discarded by the end of the current action:
      #
      #     flash.discard              # discard the entire flash at the end of the current action
      #     flash.discard(:warning)    # discard only the "warning" entry at the end of the current action
      def discard(k = nil)
        k = k.to_s if k
        @discard.merge Array(k || keys)
        k ? self[k] : self
      end

      # Mark for removal entries that were kept, and delete unkept ones.
      #
      # This method is called automatically by filters, so you generally don't need to care about it.
      def sweep #:nodoc:
        @discard.each { |k| @flashes.delete k }
        @discard.replace @flashes.keys
      end

      # Convenience accessor for <tt>flash[:alert]</tt>.
      def alert
        self[:alert]
      end

      # Convenience accessor for <tt>flash[:alert]=</tt>.
      def alert=(message)
        self[:alert] = message
      end

      # Convenience accessor for <tt>flash[:notice]</tt>.
      def notice
        self[:notice]
      end

      # Convenience accessor for <tt>flash[:notice]=</tt>.
      def notice=(message)
        self[:notice] = message
      end

      protected
      def now_is_loaded?
        @now
      end

      def stringify_array(array)
        array.map do |item|
          item.kind_of?(Symbol) ? item.to_s : item
        end
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      session    = Request::Session.find(env) || {}
      flash_hash = env[KEY]

      if flash_hash && (flash_hash.present? || session.key?('flash'))
        session["flash"] = flash_hash.to_session_value
        env[KEY] = flash_hash.dup
      end

      if (!session.respond_to?(:loaded?) || session.loaded?) && # (reset_session uses {}, which doesn't implement #loaded?)
        session.key?('flash') && session['flash'].nil?
        session.delete('flash')
      end
    end
  end
end

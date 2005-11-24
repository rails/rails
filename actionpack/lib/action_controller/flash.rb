module ActionController #:nodoc:
  # The flash provides a way to pass temporary objects between actions. Anything you place in the flash will be exposed
  # to the very next action and then cleared out. This is a great way of doing notices and alerts, such as a create action
  # that sets <tt>flash[:notice] = "Successfully created"</tt> before redirecting to a display action that can then expose 
  # the flash to its template. Actually, that exposure is automatically done. Example:
  #
  #   class WeblogController < ActionController::Base
  #     def create
  #       # save post
  #       flash[:notice] = "Successfully created post"
  #       redirect_to :action => "display", :params => { :id => post.id }
  #     end
  #
  #     def display
  #       # doesn't need to assign the flash notice to the template, that's done automatically
  #     end
  #   end
  #
  #   display.rhtml
  #     <% if @flash[:notice] %><div class="notice"><%= @flash[:notice] %></div><% end %>
  #
  # This example just places a string in the flash, but you can put any object in there. And of course, you can put as many
  # as you like at a time too. Just remember: They'll be gone by the time the next action has been performed.
  #
  # See docs on the FlashHash class for more details about the flash.
  module Flash
    def self.append_features(base) #:nodoc:
      super
      base.before_filter(:fire_flash)
      base.after_filter(:sweep_flash)
    end

    class FlashNow #:nodoc:
      def initialize flash
        @flash = flash
      end
      
      def []=(k, v)
        @flash[k] = v
        @flash.discard(k)
        v
      end
      
      def [](k)
        @flash[k]
      end
    end
    
    class FlashHash < Hash
      @@avoid_sweep = false
      cattr_accessor :avoid_sweep
      
      def initialize #:nodoc:
        super
        @used = {}
      end
      
      def []=(k, v) #:nodoc:
        keep(k)
        super
      end
      
      def update h #:nodoc:
        h.keys.each{|k| discard k }
        super
      end
      
      alias merge! update
      
      def replace h #:nodoc:
        @used = {}
        super
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
      def now
        FlashNow.new self
      end
    
      # Keeps either the entire current flash or a specific flash entry available for the next action:
      #
      #    flash.keep            # keeps the entire flash
      #    flash.keep(:notice)   # keeps only the "notice" entry, the rest of the flash is discarded
      def keep(k=nil)
        use(k, false)
      end
    
      # Marks the entire flash or a single flash entry to be discarded by the end of the current action
      #
      #     flash.keep                 # keep entire flash available for the next action
      #     flash.discard(:warning)    # discard the "warning" entry (it'll still be available for the current action)
      def discard(k=nil)
        use(k)
      end
    
      # Mark for removal entries that were kept, and delete unkept ones.
      #
      # This method is called automatically by filters, so you generally don't need to care about it.
      def sweep #:nodoc:
        return if @@avoid_sweep
        keys.each do |k| 
          unless @used[k]
            use(k)
          else
            delete(k)
            @used.delete(k)
          end
        end
        (@used.keys - keys).each{|k| @used.delete k } # clean up after keys that could have been left over by calling reject! or shift on the flash
      end
    
      private
        # Used internally by the <tt>keep</tt> and <tt>discard</tt> methods
        #     use()               # marks the entire flash as used
        #     use('msg')          # marks the "msg" entry as used
        #     use(nil, false)     # marks the entire flash as unused (keeps it around for one more action)
        #     use('msg', false)   # marks the "msg" entry as unused (keeps it around for one more action)
        def use(k=nil, v=true)
          unless k.nil?
            @used[k] = v
          else
            keys.each{|key| use key, v }
          end
        end
    end


    protected 
      # Access the contents of the flash. Use <tt>flash["notice"]</tt> to read a notice you put there or 
      # <tt>flash["notice"] = "hello"</tt> to put a new one.
      # Note that if sessions are disabled only flash.now will work.
      def flash #:doc:
        # @session = Hash.new if sessions are disabled
        if @session.is_a?(Hash)
          @__flash ||= FlashHash.new

        # otherwise, @session is a CGI::Session or a TestSession
        else
          @session['flash'] ||= FlashHash.new
        end
      end

      # deprecated. use <tt>flash.keep</tt> instead
      def keep_flash #:doc:
        warn 'keep_flash is deprecated; use flash.keep instead.'
        flash.keep
      end


    private
  
      # marks flash entries as used and expose the flash to the view 
      def fire_flash
        flash.discard
        @assigns["flash"] = flash
      end
  
      # deletes the flash entries that were not marked for keeping
      def sweep_flash
        flash.sweep
      end  
  end
end

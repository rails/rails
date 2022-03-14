# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "action_dispatch/request/flash/flash_now"

module ActionDispatch
  class Request
    module Flash
      class FlashHash
        include Enumerable

        def self.from_session_value(value) # :nodoc:
          case value
          when FlashHash # Rails 3.1, 3.2
            flashes = value.instance_variable_get(:@flashes)
            if discard = value.instance_variable_get(:@used)
              flashes.except!(*discard)
            end
            new(flashes, flashes.keys)
          when Hash # Rails 4.0
            flashes = value["flashes"]
            if discard = value["discard"]
              flashes.except!(*discard)
            end
            new(flashes, flashes.keys)
          else
            new
          end
        end

        # Builds a hash containing the flashes to keep for the next request.
        # If there are none to keep, returns +nil+.
        def to_session_value # :nodoc:
          flashes_to_keep = @flashes.except(*@discard)
          return nil if flashes_to_keep.empty?
          { "discard" => [], "flashes" => flashes_to_keep }
        end

        def initialize(flashes = {}, discard = []) # :nodoc:
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

        def update(h) # :nodoc:
          @discard.subtract stringify_array(h.keys)
          @flashes.update h.stringify_keys
          self
        end

        def keys
          @flashes.keys
        end

        def key?(name)
          @flashes.key? name.to_s
        end

        # Immediately deletes the single flash entry. Use this method when you
        # want remove the message within the current action. See also #discard.
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

        def replace(h) # :nodoc:
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
        #
        # Use this method when you want to display the message in the current
        # action but not in the next one. See also #delete.
        def discard(k = nil)
          k = k.to_s if k
          @discard.merge Array(k || keys)
          k ? self[k] : self
        end

        # Mark for removal entries that were kept, and delete unkept ones.
        #
        # This method is called automatically by filters, so you generally don't need to care about it.
        def sweep # :nodoc:
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

        private
          def stringify_array(array) # :doc:
            array.map do |item|
              item.kind_of?(Symbol) ? item.to_s : item
            end
          end
      end
    end
  end
end

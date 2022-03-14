# frozen_string_literal: true

require "action_dispatch/request/flash/flash_hash"

module ActionDispatch
  class Request
    module Flash
      module RequestMethods
        # Access the contents of the flash. Returns a ActionDispatch::Flash::FlashHash.
        #
        # See ActionDispatch::Flash for example usage.
        def flash
          flash = flash_hash
          return flash if flash
          self.flash = Flash::FlashHash.from_session_value(session["flash"])
        end

        def flash=(flash)
          set_header Flash::KEY, flash
        end

        def flash_hash # :nodoc:
          get_header Flash::KEY
        end

        def commit_flash # :nodoc:
          return unless session.enabled?

          if flash_hash && (flash_hash.present? || session.key?("flash"))
            session["flash"] = flash_hash.to_session_value
            self.flash = flash_hash.dup
          end

          if session.loaded? && session.key?("flash") && session["flash"].nil?
            session.delete("flash")
          end
        end

        def reset_session # :nodoc:
          super
          self.flash = nil
        end
      end
    end
  end
end

# cgi/session/memcached.rb - persistent storage of marshalled session data
#
# == Overview
#
# This file provides the CGI::Session::MemCache class, which builds
# persistence of storage data on top of the MemCache library.  See
# cgi/session.rb for more details on session storage managers.
#

begin
  require 'cgi/session'
  require 'memcache'

  class CGI
    class Session
      # MemCache-based session storage class.
      #
      # This builds upon the top-level MemCache class provided by the
      # library file memcache.rb.  Session data is marshalled and stored
      # in a memcached cache.
      class MemCacheStore
        def check_id(id) #:nodoc:#
          /[^0-9a-zA-Z]+/ =~ id.to_s ? false : true
        end

        # Create a new CGI::Session::MemCache instance
        #
        # This constructor is used internally by CGI::Session. The
        # user does not generally need to call it directly.
        #
        # +session+ is the session for which this instance is being
        # created. The session id must only contain alphanumeric
        # characters; automatically generated session ids observe
        # this requirement.
        #
        # +options+ is a hash of options for the initializer. The
        # following options are recognized:
        #
        # cache::  an instance of a MemCache client to use as the
        #      session cache.
        #
        # expires:: an expiry time value to use for session entries in
        #     the session cache. +expires+ is interpreted in seconds
        #     relative to the current time if it’s less than 60*60*24*30
        #     (30 days), or as an absolute Unix time (e.g., Time#to_i) if
        #     greater. If +expires+ is +0+, or not passed on +options+,
        #     the entry will never expire.
        #
        # This session's memcache entry will be created if it does
        # not exist, or retrieved if it does.
        def initialize(session, options = {})
          id = session.session_id
          unless check_id(id)
            raise ArgumentError, "session_id '%s' is invalid" % id
          end
          @cache = options['cache'] || MemCache.new('localhost')
          @expires = options['expires'] || 0
          @session_key = "session:#{id}"
          @session_data = {}
        end

        # Restore session state from the session's memcache entry.
        #
        # Returns the session state as a hash.
        def restore
          begin
            @session_data = @cache[@session_key] || {}
          rescue
            @session_data = {}
          end
        end

        # Save session state to the session's memcache entry.
        def update
          begin
            @cache.set(@session_key, @session_data, @expires)
          rescue
            # Ignore session update failures.
          end
        end
      
        # Update and close the session's memcache entry.
        def close
          update
        end

        # Delete the session's memcache entry.
        def delete
          begin
            @cache.delete(@session_key)
          rescue
            # Ignore session delete failures.
          end
          @session_data = {}
        end
        
        def data
          @session_data
        end
      end
    end
  end
rescue LoadError
  # MemCache wasn't available so neither can the store be
end

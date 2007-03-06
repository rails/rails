# CGI::Session#create_new_id requires 'digest/md5' on every call.  This makes
# sense when spawning processes per request, but is unnecessarily expensive
# when serving requests from a long-lived process.
#
# http://railsexpress.de/blog/articles/2005/11/22/speeding-up-the-creation-of-new-sessions
#
# Also expose the CGI instance to session stores.
require 'cgi/session'
require 'digest/md5'

class CGI
  class Session #:nodoc:
    # Generate an MD5 hash including the time, a random number, the process id,
    # and a constant string. This is used to generate session ids but may be
    # reused elsewhere.
    def self.generate_unique_id(constant = 'foobar')
      md5 = Digest::MD5.new
      now = Time.now
      md5 << now.to_s
      md5 << String(now.usec)
      md5 << String(rand(0))
      md5 << String($$)
      md5 << constant
      md5.hexdigest
    end

    # Make the CGI instance available to session stores.
    attr_reader :cgi
    attr_reader :dbman
    alias_method :initialize_without_cgi_reader, :initialize
    def initialize(cgi, options = {})
      @cgi = cgi
      initialize_without_cgi_reader(cgi, options)
    end

    private
      # Create a new session id.
      def create_new_id
        @new_session = true
        self.class.generate_unique_id
      end
  end
end

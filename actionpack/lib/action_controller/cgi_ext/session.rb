require 'digest/md5'
require 'cgi/session'
require 'cgi/session/pstore'

class CGI #:nodoc:
  # * Expose the CGI instance to session stores.
  # * Don't require 'digest/md5' whenever a new session id is generated.
  class Session #:nodoc:
    begin
      require 'securerandom'

      # Generate a 32-character unique id using SecureRandom.
      # This is used to generate session ids but may be reused elsewhere.
      def self.generate_unique_id(constant = nil)
        SecureRandom.hex(16)
      end
    rescue LoadError
      # Generate an 32-character unique id based on a hash of the current time,
      # a random number, the process id, and a constant string. This is used
      # to generate session ids but may be reused elsewhere.
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

    # * Don't require 'digest/md5' whenever a new session is started.
    class PStore #:nodoc:
      def initialize(session, option={})
        dir = option['tmpdir'] || Dir::tmpdir
        prefix = option['prefix'] || ''
        id = session.session_id
        md5 = Digest::MD5.hexdigest(id)[0,16]
        path = dir+"/"+prefix+md5
        path.untaint
        if File::exist?(path)
          @hash = nil
        else
          unless session.new_session
            raise CGI::Session::NoSession, "uninitialized session"
          end
          @hash = {}
        end
        @p = ::PStore.new(path)
        @p.transaction do |p|
          File.chmod(0600, p.path)
        end
      end
    end
  end
end

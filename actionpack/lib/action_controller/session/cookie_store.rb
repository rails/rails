require 'cgi'
require 'cgi/session'
require 'base64'        # to make marshaled data HTTP header friendly
require 'digest/sha2'   # to generate the data integrity hash

# This cookie-based session store is the Rails default. Sessions typically
# contain at most a user_id and flash message; both fit within the 4K cookie
# size limit. Cookie-based sessions are dramatically faster than the
# alternatives.
#
# A secure hash is included with the cookie to ensure data integrity:
# a user cannot alter his user_id without knowing the secret key included in
# the hash. New apps are generated with a session :secret option in
# Application Controller. Set your own for old apps you're upgrading.
# Note that changing the secret invalidates all existing sessions!
#
# If you have more than 4K of session data or don't want your data to be
# visible to the user, pick another session store.
#
# CookieOverflow is raised if you attempt to store more than 4K of data.
# TamperedWithCookie is raised if the data integrity check fails.
class CGI::Session::CookieStore
  # Cookies can typically store 4096 bytes.
  MAX = 4096

  # Raised when storing more than 4K of session data.
  class CookieOverflow < StandardError; end

  # Raised when the cookie fails its integrity check.
  class TamperedWithCookie < StandardError; end

  # Called from CGI::Session only.
  def initialize(session, options = {})
    # The secret option is required.
    if options['secret'].blank?
      raise ArgumentError, 'A secret is required to generate an integrity hash for cookie session data. Use session :secret => "some secret phrase" in ApplicationController.'
    end

    # Keep the session and its secret on hand so we can read and write cookies.
    @session, @secret = session, options['secret']

    # Default cookie options derived from session settings.
    @cookie_options = {
      'name'    => options['session_key'],
      'path'    => options['session_path'],
      'domain'  => options['session_domain'],
      'expires' => options['session_expires'],
      'secure'  => options['session_secure']
    }

    # Set no_hidden and no_cookies since the session id is unused and we
    # set our own data cookie.
    options['no_hidden'] = true
    options['no_cookies'] = true
  end

  # Restore session data from the cookie.
  def restore
    @original = read_cookie
    @data = unmarshal(@original) || {}
  end

  # Wait until close to write the session data cookie.
  def update; end

  # Write the session data cookie if it was loaded and has changed.
  def close
    if defined? @data
      updated = marshal(@data)
      raise CookieOverflow if updated.size > MAX
      write_cookie('value' => updated) unless updated == @original
    end
  end

  # Delete the session data by setting an expired cookie with no data.
  def delete
    write_cookie('value' => '', 'expires' => 1.year.ago)
  end

  private
    # Marshal a session hash into safe cookie data. Include an integrity hash.
    def marshal(session)
      data = Base64.encode64(Marshal.dump(session)).chop
      CGI.escape "#{data}--#{generate_digest(data)}"
    end

    # Unmarshal cookie data to a hash and verify its integrity.
    def unmarshal(cookie)
      if cookie
        data, digest = CGI.unescape(cookie).split('--')
        raise TamperedWithCookie unless digest == generate_digest(data)
        Marshal.load(Base64.decode64(data))
      end
    end

    # Generate the inline SHA512 message digest. Larger (128 bytes) than SHA256
    # (64 bytes) or RMD160 (40 bytes), but small relative to the 4096 byte
    # max cookie size.
    def generate_digest(data)
      Digest::SHA512.hexdigest "#{data}#{@secret}"
    end

    # Read the session data cookie.
    def read_cookie
      @session.cgi.cookies[@cookie_options['name']].first
    end

    # CGI likes to make you hack.
    def write_cookie(options)
      cookie = CGI::Cookie.new(@cookie_options.merge(options))
      @session.cgi.send :instance_variable_set, '@output_cookies', [cookie]
    end
end

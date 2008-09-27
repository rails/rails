require 'cgi'
require 'cgi/session'
require 'openssl'       # to generate the HMAC message digest

# This cookie-based session store is the Rails default. Sessions typically
# contain at most a user_id and flash message; both fit within the 4K cookie
# size limit. Cookie-based sessions are dramatically faster than the
# alternatives.
#
# If you have more than 4K of session data or don't want your data to be
# visible to the user, pick another session store.
#
# CookieOverflow is raised if you attempt to store more than 4K of data.
# TamperedWithCookie is raised if the data integrity check fails.
#
# A message digest is included with the cookie to ensure data integrity:
# a user cannot alter his +user_id+ without knowing the secret key included in
# the hash. New apps are generated with a pregenerated secret in
# config/environment.rb. Set your own for old apps you're upgrading.
#
# Session options:
#
# * <tt>:secret</tt>: An application-wide key string or block returning a string
#   called per generated digest. The block is called with the CGI::Session
#   instance as an argument. It's important that the secret is not vulnerable to
#   a dictionary attack. Therefore, you should choose a secret consisting of
#   random numbers and letters and more than 30 characters. Examples:
#
#     :secret => '449fe2e7daee471bffae2fd8dc02313d'
#     :secret => Proc.new { User.current_user.secret_key }
#
# * <tt>:digest</tt>: The message digest algorithm used to verify session
#   integrity defaults to 'SHA1' but may be any digest provided by OpenSSL,
#   such as 'MD5', 'RIPEMD160', 'SHA256', etc.
#
# To generate a secret key for an existing application, run
# "rake secret" and set the key in config/environment.rb.
#
# Note that changing digest or secret invalidates all existing sessions!
class CGI::Session::CookieStore
  # Cookies can typically store 4096 bytes.
  MAX = 4096
  SECRET_MIN_LENGTH = 30 # characters

  # Raised when storing more than 4K of session data.
  class CookieOverflow < StandardError; end

  # Raised when the cookie fails its integrity check.
  class TamperedWithCookie < StandardError; end

  # Called from CGI::Session only.
  def initialize(session, options = {})
    # The session_key option is required.
    if options['session_key'].blank?
      raise ArgumentError, 'A session_key is required to write a cookie containing the session data. Use config.action_controller.session = { :session_key => "_myapp_session", :secret => "some secret phrase" } in config/environment.rb'
    end

    # The secret option is required.
    ensure_secret_secure(options['secret'])

    # Keep the session and its secret on hand so we can read and write cookies.
    @session, @secret = session, options['secret']

    # Message digest defaults to SHA1.
    @digest = options['digest'] || 'SHA1'

    # Default cookie options derived from session settings.
    @cookie_options = {
      'name'    => options['session_key'],
      'path'    => options['session_path'],
      'domain'  => options['session_domain'],
      'expires' => options['session_expires'],
      'secure'  => options['session_secure'],
      'http_only' => options['session_http_only']
    }

    # Set no_hidden and no_cookies since the session id is unused and we
    # set our own data cookie.
    options['no_hidden'] = true
    options['no_cookies'] = true
  end

  # To prevent users from using something insecure like "Password" we make sure that the
  # secret they've provided is at least 30 characters in length.
  def ensure_secret_secure(secret)
    # There's no way we can do this check if they've provided a proc for the
    # secret.
    return true if secret.is_a?(Proc)

    if secret.blank?
      raise ArgumentError, %Q{A secret is required to generate an integrity hash for cookie session data. Use config.action_controller.session = { :session_key => "_myapp_session", :secret => "some secret phrase of at least #{SECRET_MIN_LENGTH} characters" } in config/environment.rb}
    end

    if secret.length < SECRET_MIN_LENGTH
      raise ArgumentError, %Q{Secret should be something secure, like "#{CGI::Session.generate_unique_id}".  The value you provided, "#{secret}", is shorter than the minimum length of #{SECRET_MIN_LENGTH} characters}
    end
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
    if defined?(@data) && !@data.blank?
      updated = marshal(@data)
      raise CookieOverflow if updated.size > MAX
      write_cookie('value' => updated) unless updated == @original
    end
  end

  # Delete the session data by setting an expired cookie with no data.
  def delete
    @data = nil
    clear_old_cookie_value
    write_cookie('value' => nil, 'expires' => 1.year.ago)
  end

  # Generate the HMAC keyed message digest. Uses SHA1 by default.
  def generate_digest(data)
    key = @secret.respond_to?(:call) ? @secret.call(@session) : @secret
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new(@digest), key, data)
  end

  private
    # Marshal a session hash into safe cookie data. Include an integrity hash.
    def marshal(session)
      data = ActiveSupport::Base64.encode64s(Marshal.dump(session))
      "#{data}--#{generate_digest(data)}"
    end

    # Unmarshal cookie data to a hash and verify its integrity.
    def unmarshal(cookie)
      if cookie
        data, digest = cookie.split('--')

        # Do two checks to transparently support old double-escaped data.
        unless digest == generate_digest(data) || digest == generate_digest(data = CGI.unescape(data))
          delete
          raise TamperedWithCookie
        end

        Marshal.load(ActiveSupport::Base64.decode64(data))
      end
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

    # Clear cookie value so subsequent new_session doesn't reload old data.
    def clear_old_cookie_value
      @session.cgi.cookies[@cookie_options['name']].clear
    end
end

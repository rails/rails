require 'net/ssh'

module SwitchTower
  # A helper class for dealing with SSH connections.
  class SSH
    # An abstraction to make it possible to connect to the server via public key
    # without prompting for the password. If the public key authentication fails
    # this will fall back to password authentication.
    #
    # If a block is given, the new session is yielded to it, otherwise the new
    # session is returned.
    def self.connect(server, config, port=22, &block)
      methods = [ %w(publickey hostbased), %w(password keyboard-interactive) ]
      password_value = nil

      begin
        Net::SSH.start(server,
          :username => config.user,
          :password => password_value,
          :port => port,
          :auth_methods => methods.shift,
          &block)
      rescue Net::SSH::AuthenticationFailed
        raise if methods.empty?
        password_value = config.password
        retry
      end
    end
  end
end

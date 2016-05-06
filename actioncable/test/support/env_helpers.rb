module EnvHelpers
  def default_env(options = {})
    Rack::MockRequest.env_for(
    "/test", { 'HTTP_CONNECTION' => 'upgrade', 'HTTP_UPGRADE' => 'websocket', 'HTTP_HOST' => 'localhost',
      'HTTP_ORIGIN' => 'http://rubyonrails.com' }.merge!(options)
    )
  end

  def rack_hijack_env(options = {})
    env = default_env
    env.merge!({ 'rack.hijack' => -> { env['rack.hijack_io'] = StringIO.new } })
  end
end

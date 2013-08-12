require 'abstract_unit'

class UrlTest < ActiveSupport::TestCase

  def url(options={})
    ::ActionDispatch::Url.new(options)
  end

  def test_url(options={})
    url({ host: 'example.com' }.merge(options))
  end

  def assert_relative(path, options={})
    assert_equal(path, url(options).relative_path)
  end

  def assert_absolute(path, options={})
    assert_equal(path, url(options).absolute_path)
  end

  test 'relative_path returns blank string when path is false' do
    assert_relative('', host: 'example.com')
    assert_relative('', host: 'example.com', path: '')
    assert_relative('', host: 'example.com', path: nil)
    assert_relative('', host: 'example.com', path: false)
    assert_relative('?sort=asc', host: 'example.com', path: nil, params: {sort: 'asc'})
    assert_relative('#anchor', host: 'example.com', path: nil, anchor: 'anchor')
    assert_relative('?sort=asc#anchor', host: 'example.com', path: nil, params: {sort: 'asc'}, anchor: 'anchor')
  end

  test 'relative_path joins path, params, and anchor' do
    assert_relative('/c/a/1', host: 'example.com', path: '/c/a/1')
    assert_relative('/c/a/1?sort=asc', host: 'example.com', path: '/c/a/1', params: {sort: 'asc'})
    assert_relative('/c/a/1#anchor', host: 'example.com', path: '/c/a/1', anchor: 'anchor')
    assert_relative('/c/a/1?sort=asc#anchor', host: 'example.com', path: '/c/a/1', params: {sort: 'asc'}, anchor: 'anchor')
  end

  test 'relative_path adds optional trailing_slash' do
    options = { host: 'example.com', path: '/c/a/1', trailing_slash: true }
    assert_relative('/c/a/1/', options)
    assert_relative('/c/a/1/', options.merge(path: '/c/a/1/'))
    assert_relative('/c/a/1/?sort=asc', options.merge(params: {sort: 'asc'}))
    assert_relative('/c/a/1/#anchor', options.merge(anchor: 'anchor'))
    assert_relative('/c/a/1/?sort=asc#anchor', options.merge(params: {sort: 'asc'}, anchor: 'anchor'))
  end

  test 'relative_path does not add double trailing slash' do
    assert_relative '/', host: 'example.com',  path: '',  trailing_slash: true
    assert_relative '/', host: 'example.com/', path: '',  trailing_slash: true
    assert_relative '/', host: 'example.com',  path: '/', trailing_slash: true
    assert_relative '/', host: 'example.com/', path: '/', trailing_slash: true
  end

  test 'relative_path does not require host' do
    assert_equal('/c/a/1', url(path: '/c/a/1').relative_path)
  end

  test 'absolute_path returns full url' do
    options = { host: 'example.com' }
    assert_absolute('http://example.com', options)
    assert_absolute('http://example.com/path', options.merge(path: '/path'))
    assert_absolute('http://bob:secret@example.com/path', options.merge(path: '/path', user: 'bob', password: 'secret'))
    assert_absolute('http://example.com#anchor', options.merge(anchor: 'anchor'))
    assert_absolute('http://example.com?sort=asc', options.merge(params: {sort: 'asc'}))
    assert_absolute('http://example.com/c/a/1?sort=asc', options.merge(path: '/c/a/1', params: {sort: 'asc'}))
    assert_absolute('http://api.example.com/c/a/1?sort=asc#anchor', options.merge(path: '/c/a/1', params: {sort: 'asc'}, anchor: 'anchor', subdomain: 'api'))
  end

  test 'absolute_path adds optional trailing slash' do
    options = { host: 'example.com', trailing_slash: true }
    assert_absolute('http://example.com/', options)
    assert_absolute('http://example.com/path/', options.merge(path: '/path'))
    assert_absolute('http://example.com/#anchor', options.merge(anchor: 'anchor'))
    assert_absolute('http://example.com/?sort=asc', options.merge(params: {sort: 'asc'}))
    assert_absolute('http://example.com/c/a/1/?sort=asc', options.merge(path: '/c/a/1', params: {sort: 'asc'}))
    assert_absolute('http://api.example.com/c/a/1/?sort=asc#anchor', options.merge(path: '/c/a/1', params: {sort: 'asc'}, anchor: 'anchor', subdomain: 'api'))
  end

  test 'absolute_path raises ArgumentError without host' do
    assert_raises(ArgumentError) { url(path: '/c/a/1').absolute_path }
  end


  test 'initialize parses options[:host] uri into parts' do
    assert_equal({ host: 'example.com', host_protocol: nil, host_port: nil },
                 url(host: 'example.com').options)
    assert_equal({ host: 'example.com', host_protocol: 'http://', host_port: nil },
                 url(host: 'http://example.com').options)
    assert_equal({ host: 'example.com', host_protocol: 'https://', host_port: nil },
                 url(host: 'https://example.com').options)
    assert_equal({ host: 'example.com', host_protocol: 'http://', host_port: '3000' },
                 url(host: 'http://example.com:3000').options)
    assert_equal({ host: 'example.com', host_protocol: 'https://', host_port: '3000' },
                 url(host: 'https://example.com:3000').options)
  end

  test 'initialize does not parse protocol relative options[:host]' do
    # TODO: what is the correct behavior?
    assert_equal({ host: '//example.com', host_protocol: nil, host_port: nil },
                 url(host: '//example.com').options)
  end

  test 'protocol_string returns http when nil' do
    assert_equal('http://', test_url(protocol: nil).protocol_string)
  end

  test 'protocol_string returns relative protocol when false' do
    assert_equal('//', test_url(protocol: false).protocol_string)
    assert_equal('//', test_url(protocol: '//').protocol_string)
  end

  test 'protocol_string returns protocol when valid' do
    assert_equal('https://', test_url(protocol: 'https://').protocol_string)
    assert_equal('ftp://', test_url(protocol: 'ftp://').protocol_string)
  end

  test 'protocol_string accepts protocol without separator' do
    assert_equal('https://', test_url(protocol: 'https').protocol_string)
    assert_equal('https://', test_url(protocol: 'https:').protocol_string)
    assert_equal('https://', test_url(protocol: 'https://').protocol_string)
  end

  test 'protocol_string defaults to protocol parsed from options[:host]' do
    assert_equal('ftp://', url(host: 'ftp://example.com').protocol_string)
    assert_equal('ftp://', url(host: 'ftp://example.com', protocol: nil).protocol_string)
    assert_equal('https://', url(host: 'ftp://example.com', protocol: 'https').protocol_string)
    assert_equal('https://', url(host: 'example.com', protocol: 'https').protocol_string)
    assert_equal('ftp://', url(host: 'example.com', protocol: 'ftp').protocol_string)
  end

  test 'protocol_string raises ArgumentError when protocol is invalid' do
    assert_raises(ArgumentError) { test_url(protocol: ':invalid').protocol_string }
  end

  test 'auth_string returns blank string without authentication' do
    assert_equal('', url(host: 'example.com').auth_string)
  end

  test 'auth_string returns blank string unless both user and password are given' do
    assert_equal('', url(host: 'example.com', user: 'bob').auth_string)
    assert_equal('', url(host: 'example.com', password: 'secret').auth_string)
  end

  test 'auth_string returns username and password with authentication' do
    assert_equal('bob:secret@', url(host: 'example.com', user: 'bob', password: 'secret').auth_string)
  end

  test 'auth_string escapes username and password' do
    assert_equal('b%26b:s%3Fcr%26t@', url(host: 'example.com', user: 'b&b', password: 's?cr&t').auth_string)
  end

  test 'host_string raises ArgumentError if options[:host] is missing' do
    assert_raises(ArgumentError) { url.host_string }
  end

  test 'host_string defaults to options[:host]' do
    assert_equal('example.com', url(host: 'example.com').host_string)
    assert_equal('api.example.com', url(host: 'api.example.com').host_string)
    assert_equal('www.example.com', url(host: 'http://www.example.com:3000').host_string)
  end

  test 'host_string returns IP if host is IP address' do
    assert_equal('127.0.0.1', url(host: '127.0.0.1').host_string)
  end

  test 'host_string does not prepend subdomain if host is IP address' do
    assert_equal('127.0.0.1', url(host: '127.0.0.1', subdomain: 'api').host_string)
  end

  test 'host_string replaces domain when given' do
    assert_equal('37signals.com', url(host: 'example.com', domain: '37signals.com').host_string)
    assert_equal('37signals.com', url(host: '127.0.0.1', domain: '37signals.com').host_string)
    assert_equal('api.37signals.com', url(host: 'api.example.com', domain: '37signals.com').host_string)
  end

  test 'host_string does not replace domain if falsey' do
    assert_equal('www.example.com', url(host: 'www.example.com', domain: '').host_string)
    assert_equal('www.example.com', url(host: 'www.example.com', domain: nil).host_string)
    assert_equal('www.example.com', url(host: 'www.example.com', domain: false).host_string)
  end

  test 'host_string replaces subdomain when given' do
    assert_equal('api.example.com', url(host: 'example.com', subdomain: 'api').host_string)
    assert_equal('api.example.com', url(host: 'www.example.com', subdomain: 'api').host_string)
    assert_equal('api.example.com', url(host: 'ns1.www.example.com', subdomain: 'api').host_string)
    assert_equal('api.37signals.com', url(host: 'example.com', subdomain: 'api', domain: '37signals.com').host_string)
  end

  test 'host_string removes all subdomains if falsey' do
    assert_equal('example.com', url(host: 'api.example.com', subdomain: '').host_string)
    assert_equal('example.com', url(host: 'www.example.com', subdomain: nil).host_string)
    assert_equal('example.com', url(host: 'ns1.www.example.com', subdomain: false).host_string)
    assert_equal('37signals.com', url(host: 'api.example.com', subdomain: nil, domain: '37signals.com').host_string)
  end

  test 'host_string keeps subdomain if true' do
    assert_equal('api.example.com', url(host: 'api.example.com', subdomain: true).host_string)
  end

  test 'host_string calls #to_param on subdomain object' do
    assert_equal('www.example.com', url(host: 'example.com', subdomain: mock(to_param: 'www')).host_string)
    assert_equal('www.example.com', url(host: 'api.example.com', subdomain: mock(to_param: 'www')).host_string)
    assert_equal('example.com', url(host: 'api.example.com', subdomain: mock(to_param: '')).host_string)
  end

  test 'host_string defaults to TLD length 1' do
    assert_equal('api.co.uk', url(host: 'www.example.co.uk', subdomain: 'api').host_string)
    assert_equal('api.example.co.uk', url(host: 'www.example.co.uk', subdomain: 'api', tld_length: 2).host_string)
    assert_equal('api.example.example.com', url(host: 'api.example.co.uk', domain: 'example.com').host_string)
    assert_equal('api.example.com', url(host: 'api.example.co.uk', domain: 'example.com', tld_length: 2).host_string)
  end

  test 'host_string replaces domain and subdomain for host IP address' do
    assert_equal('api.example.com', url(host: '127.0.0.1', subdomain: 'api', domain: 'example.com').host_string)
  end

  test 'host_string chomps trailing slash' do
    assert_equal('test.host', url(host: 'test.host/').host_string)
    assert_equal('127.0.0.1', url(host: '127.0.0.1/').host_string)
    assert_equal('example.com', url(host: 'test.host', domain: 'example.com/').host_string)
  end

  test 'port_string returns empty string for default ports' do
    assert_equal('', test_url(protocol: 'http://', port: 80).port_string)
    assert_equal('', test_url(protocol: 'https://', port: 443).port_string)
  end

  test 'port_string returns empty string when disabled' do
    assert_equal(':8443', url(host: 'http://example.com:8443').port_string)
    assert_equal('', url(host: 'http://example.com:8443', port: nil).port_string)
    assert_equal('', url(host: 'http://example.com:8443', port: false).port_string)
  end

  test 'port_string returns :port for custom port' do
    assert_equal(':3000', test_url(protocol: 'http://', port: 3000).port_string)
    assert_equal(':80', test_url(protocol: 'https://', port: 80).port_string)
    assert_equal(':443', test_url(protocol: 'http://', port: 443).port_string)
  end

  test 'port_string accounts for parsed host protocol' do
    assert_equal(':3000', url(host: 'http://www.example.com:3000').port_string)
    assert_equal('', url(host: 'https://www.example.com:443').port_string)
    assert_equal('', url(host: 'https://www.example.com', port: 443).port_string)
  end

  test 'port_string returns empty string for relative protocols and known ports' do
    # TODO: Should this only be blank for :80 and :443?
    assert_equal('', test_url(protocol: false).port_string)
    assert_equal('', test_url(protocol: false, port: 80).port_string)
    assert_equal('', test_url(protocol: false, port: 443).port_string)
    assert_equal(':3000', test_url(protocol: '//', port: 3000).port_string)
  end

  test 'script_name_string returns empty string when false' do
    assert_equal('', url(host: 'example.com').script_name_string)
    assert_equal('', url(host: 'example.com', script_name: nil).script_name_string)
    assert_equal('', url(host: 'example.com', script_name: false).script_name_string)
  end

  test 'script_name_string returns string if given' do
    assert_equal('/app', url(host: 'example.com', script_name: '/app').script_name_string)
  end

  test 'script_name_string removes trailing slash' do
    assert_equal('/app', url(host: 'example.com', script_name: '/app/').script_name_string)
  end

  test 'path_string returns normalized path' do
    assert_equal('/c/a/1', url(host: 'example.com', path: '/c/a/1').path_string)
  end

  test 'path_string removes trailing slash' do
    assert_equal('/c/a/1', url(host: 'example.com', path: '/c/a/1/').path_string)
    assert_equal('/', url(host: 'example.com', path: '/').path_string)
    assert_equal('', url(host: 'example.com', path: '').path_string)
  end

  test 'path_string parses existing params' do
    assert_equal('/c/a/1', url(host: 'example.com', path: '/c/a/1?q=code').path_string)
    assert_equal('?q=code', url(host: 'example.com', path: '/c/a/1?q=code').params_string)
    assert_equal('?q=code&sort=asc', url(host: 'example.com', path: '/c/a/1?q=code', params: {sort: 'asc'}).params_string)
  end

  test 'path_string parses and deep_merges existing params' do
    params = { a: { b: 1, c: 2 } }
    assert_equal("?#{params.to_query}", url(host: 'example.com', path: '/path?a[b]=1', params: {a: {c: 2}}).params_string)
  end

  test 'path_string parses existing anchor' do
    assert_equal('/c/a/1', url(host: 'example.com', path: '/c/a/1#anchor').path_string)
    assert_equal('#anchor', url(host: 'example.com', path: '/c/a/1#anchor').anchor_string)
    assert_equal('#heading2', url(host: 'example.com', path: '/c/a/1#anchor', anchor: 'heading2').anchor_string)
  end

  test 'path_string parses existing params and anchor' do
    assert_equal('/c/a/1', url(host: 'example.com', path: '/c/a/1?q=code#anchor').path_string)
  end

  test 'params_string returns empty string when blank' do
    assert_equal('', url(host: 'example.com', params: nil).params_string)
    assert_equal('', url(host: 'example.com', params: '').params_string)
    assert_equal('', url(host: 'example.com', params: false).params_string)
    assert_equal('', url(host: 'example.com', params: {}).params_string)
    assert_equal('', url(host: 'example.com', params: mock(to_query: '')).params_string)
  end

  test 'params_string converts hash to string' do
    assert_equal('?sort=asc', url(host: 'example.com', params: {sort: 'asc'}).params_string)
  end

  test 'params_string calls #to_query on object' do
    params = mock(:to_query => 'sort=asc')
    assert_equal('?sort=asc', url(host: 'example.com', params: params).params_string)
  end

  test 'params_string escapes characters' do
    assert_equal('?spareslashes=%2F%2F%2F%2F', url(host: 'www.example.com', path: '/books?spareslashes=////').params_string)
    assert_equal('?spareslashes=%2F%2F%2F%2F', url(host: 'www.example.com', params: { spareslashes: '////' }).params_string)
  end

  test 'anchor_string returns empty string when blank' do
    assert_equal('', url(host: 'example.com', anchor: '').anchor_string)
    assert_equal('', url(host: 'example.com', anchor: nil).anchor_string)
    assert_equal('', url(host: 'example.com', anchor: false).anchor_string)
    assert_equal('', url(host: 'example.com', anchor: mock(to_param: '')).anchor_string)
  end

  test 'anchor_string returns anchored string' do
    assert_equal('#anchor', url(host: 'example.com', anchor: 'anchor').anchor_string)
  end

  test 'anchor_string calls #to_param on object' do
    assert_equal('#anchor', url(host: 'example.com', anchor: mock(to_param: 'anchor')).anchor_string)
  end

  test 'anchor_string escapes unsafe characters' do
    assert_equal('#%23anchor', url(host: 'example.com', anchor: '#anchor').anchor_string)
    assert_equal('#%23anchor', url(host: 'example.com', anchor: mock(to_param: '#anchor')).anchor_string)
  end

  test 'anchor_string does not escape safe characters' do
    assert_equal('#name=user&email=user@domain.com', url(host: 'example.com', anchor: 'name=user&email=user@domain.com').anchor_string)
    assert_equal('#name=user&email=user@domain.com', url(host: 'example.com', anchor: mock(to_param: 'name=user&email=user@domain.com')).anchor_string)
  end

end

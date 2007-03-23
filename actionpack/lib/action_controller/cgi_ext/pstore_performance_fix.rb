# CGI::Session::PStore.initialize requires 'digest/md5' on every call.
# This makes sense when spawning processes per request, but is
# unnecessarily expensive when serving requests from a long-lived
# process.
require 'cgi/session'
require 'cgi/session/pstore'
require 'digest/md5'

class CGI::Session::PStore #:nodoc:
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

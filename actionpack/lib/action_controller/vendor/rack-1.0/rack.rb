# Copyright (C) 2007, 2008, 2009 Christian Neukirchen <purl.org/net/chneukirchen>
#
# Rack is freely distributable under the terms of an MIT-style license.
# See COPYING or http://www.opensource.org/licenses/mit-license.php.

$:.unshift(File.expand_path(File.dirname(__FILE__)))


# The Rack main module, serving as a namespace for all core Rack
# modules and classes.
#
# All modules meant for use in your application are <tt>autoload</tt>ed here,
# so it should be enough just to <tt>require rack.rb</tt> in your code.

module Rack
  # The Rack protocol version number implemented.
  VERSION = [0,1]

  # Return the Rack protocol version as a dotted string.
  def self.version
    VERSION.join(".")
  end

  # Return the Rack release as a dotted string.
  def self.release
    "1.0 bundled"
  end

  autoload :Builder, "rack/builder"
  autoload :Cascade, "rack/cascade"
  autoload :Chunked, "rack/chunked"
  autoload :CommonLogger, "rack/commonlogger"
  autoload :ConditionalGet, "rack/conditionalget"
  autoload :ContentLength, "rack/content_length"
  autoload :ContentType, "rack/content_type"
  autoload :File, "rack/file"
  autoload :Deflater, "rack/deflater"
  autoload :Directory, "rack/directory"
  autoload :ForwardRequest, "rack/recursive"
  autoload :Handler, "rack/handler"
  autoload :Head, "rack/head"
  autoload :Lint, "rack/lint"
  autoload :Lock, "rack/lock"
  autoload :MethodOverride, "rack/methodoverride"
  autoload :Mime, "rack/mime"
  autoload :Recursive, "rack/recursive"
  autoload :Reloader, "rack/reloader"
  autoload :ShowExceptions, "rack/showexceptions"
  autoload :ShowStatus, "rack/showstatus"
  autoload :Static, "rack/static"
  autoload :URLMap, "rack/urlmap"
  autoload :Utils, "rack/utils"

  autoload :MockRequest, "rack/mock"
  autoload :MockResponse, "rack/mock"

  autoload :Request, "rack/request"
  autoload :Response, "rack/response"

  module Auth
    autoload :Basic, "rack/auth/basic"
    autoload :AbstractRequest, "rack/auth/abstract/request"
    autoload :AbstractHandler, "rack/auth/abstract/handler"
    autoload :OpenID, "rack/auth/openid"
    module Digest
      autoload :MD5, "rack/auth/digest/md5"
      autoload :Nonce, "rack/auth/digest/nonce"
      autoload :Params, "rack/auth/digest/params"
      autoload :Request, "rack/auth/digest/request"
    end
  end

  module Session
    autoload :Cookie, "rack/session/cookie"
    autoload :Pool, "rack/session/pool"
    autoload :Memcache, "rack/session/memcache"
  end

  # *Adapters* connect Rack with third party web frameworks.
  #
  # Rack includes an adapter for Camping, see README for other
  # frameworks supporting Rack in their code bases.
  #
  # Refer to the submodules for framework-specific calling details.

  module Adapter
    autoload :Camping, "rack/adapter/camping"
  end
end

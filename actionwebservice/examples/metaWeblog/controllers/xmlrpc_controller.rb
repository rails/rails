#
# example controller implementing both blogger and metaWeblog APIs
# in a way that should be compatible with clients supporting both/either.
#
# test by pointing your client at http://URL/xmlrpc/api
# 

require 'meta_weblog_service'
require 'blogger_service'

class XmlrpcController < ApplicationController
  web_service_dispatching_mode :layered

  web_service :metaWeblog, MetaWeblogService.new
  web_service :blogger, BloggerService.new
end

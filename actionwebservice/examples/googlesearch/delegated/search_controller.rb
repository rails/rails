require 'google_search_service'

class SearchController < ApplicationController
  wsdl_service_name 'GoogleSearch'
  web_service_dispatching_mode :delegated
  web_service :beta3, GoogleSearchService.new
end

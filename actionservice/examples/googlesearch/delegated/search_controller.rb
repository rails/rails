require 'google_search_service'

class SearchController < ApplicationController
  wsdl_service_name 'GoogleSearch'
  service_dispatching_mode :delegated
  service :beta3, GoogleSearchService.new
end

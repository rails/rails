class GoogleSearchController < ApplicationController
  wsdl_service_name 'GoogleSearch'

  def doGetCachedPage
    "<html><body>i am a cached page. my key was %s, url was %s</body></html>" % [@params['key'], @params['url']]
  end

  def doSpellingSuggestion
    "%s: Did you mean '%s'?" % [@params['key'], @params['phrase']]
  end

  def doGoogleSearch
    resultElement = ResultElement.new
    resultElement.summary = "ONlamp.com: Rolling with Ruby on Rails"
    resultElement.URL = "http://www.onlamp.com/pub/a/onlamp/2005/01/20/rails.html"
    resultElement.snippet = "Curt Hibbs shows off Ruby on Rails by building a simple application that requires " +
                            "almost no Ruby experience. ... Rolling with Ruby on Rails. ..."
    resultElement.title = "Teh Railz0r"
    resultElement.cachedSize = "Almost no lines of code!"
    resultElement.relatedInformationPresent = true
    resultElement.hostName = "rubyonrails.com"
    resultElement.directoryCategory = category("Web Development", "UTF-8")

    result = GoogleSearchResult.new
    result.documentFiltering = @params['filter']
    result.searchComments = ""
    result.estimatedTotalResultsCount = 322000
    result.estimateIsExact = false
    result.resultElements = [resultElement]
    result.searchQuery = "http://www.google.com/search?q=ruby+on+rails"
    result.startIndex = @params['start']
    result.endIndex = @params['start'] + @params['maxResults']
    result.searchTips = "\"on\" is a very common word and was not included in your search [details]"
    result.searchTime = 0.000001

    # For Mono, we have to clone objects if they're referenced by more than one place, otherwise
    # the Ruby SOAP collapses them into one instance and uses references all over the
    # place, confusing Mono. 
    #
    # This has recently been fixed:
    #   http://bugzilla.ximian.com/show_bug.cgi?id=72265
    result.directoryCategories = [
      category("Web Development", "UTF-8"),
      category("Programming", "US-ASCII"),
    ]

    result
  end

  private
    def category(name, encoding)
      cat = DirectoryCategory.new
      cat.fullViewableName = name.dup
      cat.specialEncoding = encoding.dup
      cat
    end
end

class DirectoryCategory < ActionWebService::Struct
  member :fullViewableName, :string
  member :specialEncoding,  :string
end

class ResultElement < ActionWebService::Struct
  member :summary,                   :string
  member :URL,                       :string
  member :snippet,                   :string
  member :title,                     :string
  member :cachedSize,                :string
  member :relatedInformationPresent, :bool
  member :hostName,                  :string
  member :directoryCategory,         DirectoryCategory
  member :directoryTitle,            :string
end

class GoogleSearchResult < ActionWebService::Struct
  member :documentFiltering,          :bool
  member :searchComments,             :string
  member :estimatedTotalResultsCount, :int
  member :estimateIsExact,            :bool
  member :resultElements,             [ResultElement]
  member :searchQuery,                :string
  member :startIndex,                 :int
  member :endIndex,                   :int
  member :searchTips,                 :string
  member :directoryCategories,        [DirectoryCategory]
  member :searchTime,                 :float
end

class GoogleSearchAPI < ActionWebService::API::Base
  inflect_names false

  api_method :doGetCachedPage,         :returns => [:string], :expects => [{:key=>:string}, {:url=>:string}]
  api_method :doGetSpellingSuggestion, :returns => [:string], :expects => [{:key=>:string}, {:phrase=>:string}]

  api_method :doGoogleSearch, :returns => [GoogleSearchResult], :expects => [
    {:key=>:string},
    {:q=>:string},
    {:start=>:int},
    {:maxResults=>:int},
    {:filter=>:bool},
    {:restrict=>:string},
    {:safeSearch=>:bool},
    {:lr=>:string},
    {:ie=>:string},
    {:oe=>:string}
  ]
end

class GoogleSearchService < ActionWebService::Base
  web_service_api GoogleSearchAPI

  def doGetCachedPage(key, url)
    "<html><body>i am a cached page</body></html>"
  end

  def doSpellingSuggestion(key, phrase)
    "Did you mean 'teh'?"
  end

  def doGoogleSearch(key, q, start, maxResults, filter, restrict, safeSearch, lr, ie, oe)
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
    result.documentFiltering = filter
    result.searchComments = ""
    result.estimatedTotalResultsCount = 322000
    result.estimateIsExact = false
    result.resultElements = [resultElement]
    result.searchQuery = "http://www.google.com/search?q=ruby+on+rails"
    result.startIndex = start
    result.endIndex = start + maxResults
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

(function() {
  "use strict";

  /**
   * Search
   * ------------
   * The guide search uses a prebuilt index for searching documents.
   * Building the index in advance saves some processing time when
   * loading the page but requires more network traffic. Since the
   * index is quite large, some measures were taken to reduce the size
   * a bit:
   * - about 20 common words are ignored, such as "a", "from", "the"
   * - document references are just a number and must be looked up in
   *   `linkMap`.
   * The index is lazily downloaded when the user focuses the search
   * input and is kept in localStorage.
   */

  window.GuideSearch = {
    inProgress: false,
    lunrIndex: null,
  };

  document.addEventListener("turbolinks:load", function() {
    document.addEventListener('click', hideResults);
    // Defer loading of the index until the search box is focused,
    // because it's quite large.
    document.querySelector('.guides-search-large .search-box').addEventListener('focus', loadIndex);
    document.querySelector('.guides-search-large .search-box').addEventListener('keyup', search);
    document.querySelector('.guides-search-small .search-box').addEventListener('focus', loadIndex);
    document.querySelector('.guides-search-small .search-box').addEventListener('keyup', search);
  });

  // Return the currently active search element based on screen size
  var searchContainer = function() {
    var searchLarge = document.querySelector('.guides-search-large');
    var searchSmall = document.querySelector('.guides-search-small');
    var largeStyle = window.getComputedStyle(searchLarge);
    if(largeStyle.display === 'none') {
      return searchSmall;
    } else {
      return searchLarge;
    }
  }

  var loadIndex = function() {
    var CACHE_EXPIRATION_DAYS = 7;
    var MS_PER_DAY = 1000 * 86400;
    // Check if index is already loaded.
    if(window.GuideSearch.lunrIndex) {
      return;
    }
    // Try to load from localStorage.
    var localStorageIndex = window.localStorage.getItem('lunr-index');
    var localStorageCreation = window.localStorage.getItem('lunr-index-creation-date');
    if(localStorageIndex && localStorageCreation) {
      // Check if not expired.
      var age = new Date().getTime() - parseInt(localStorageCreation);
      if(age < MS_PER_DAY * CACHE_EXPIRATION_DAYS) {
        var data = JSON.parse(localStorageIndex);
        window.GuideSearch.lunrIndex = lunr.Index.load(data);
        return;
      }
    }
    // Load from the server and store in localStorage.
    var script = document.createElement('script');
    script.onload = function() {
      window.localStorage.setItem('lunr-index', JSON.stringify(lunrIndexData));
      window.localStorage.setItem('lunr-index-creation-date', new Date().getTime())
      window.GuideSearch.lunrIndex = lunr.Index.load(lunrIndexData);
    }
    script.src = 'javascripts/lunr-index.js';
    document.head.appendChild(script);
  }

  var hideResults = function() {
    var resultsContainer = searchContainer().querySelector('.search-results');
    resultsContainer.style.display = 'none';
  }

  var search = function() {
    var MAX_RESULT_COUNT = 5;
    var searchBox = searchContainer().querySelector('.search-box');
    var value = searchBox.value;
    var results = searchLunr(value);

    showHideResults(results.length > 0);

    for(var i = 0; i < Math.min(results.length, MAX_RESULT_COUNT); i++) {
      var result = results[i];
      // The result contains only a reference to the matched document.
      // Get the actual document to display the context.
      const doc = findDocument(result.ref);
      appendResult(doc, result);
    }
  }

  var appendResult = function(doc, result) {
    var resultsContainer = searchContainer().querySelector('.search-results');
    var resultElement = document.createElement('div');
    resultElement.classList.add('search-result');
    resultElement.innerHTML = '<div class="title">' + doc.title + '</div>' +
                              '<div class="heading">' + doc.heading + '</div>' +
                              '<div class="match">' +
                                '<span class="subheading">' + doc.subheading + '</span>' +
                                '<span class="term">' + highlight(doc, result) + '...' +
                              '</span></div>';
    resultsContainer.appendChild(resultElement);
    resultElement.addEventListener('click', onResultClick(doc));
  }

  var onResultClick = function (doc) {
    return function() {
      var url = linkMap[doc.id];
      Turbolinks.visit(url);
    }
  }

  var showHideResults = function(show) {
    var resultsContainer = searchContainer().querySelector('.search-results');
    resultsContainer.innerHTML = '';
    if(show) {
      resultsContainer.style.display = 'block';
    } else {
      resultsContainer.style.display = 'none';
    }
  }

  var searchLunr = function(term) {
    if(term.length === 0) {
      return [];
    }
    var words = term.replace(/\s+/, ' ')
                    .trim()
                    .split(' ');
    if(window.GuideSearch.inProgress) {
      return [];
    }
    // Index not yet loaded, wait and retry.
    if(!window.GuideSearch.lunrIndex) {
      showSpinner();
      window.GuideSearch.inProgress = true;
      setTimeout(function() {
        window.GuideSearch.inProgress = false;
        search();
      }, 1000);
      return [];
    }
    hideSpinner();
    // +term1 +term2 creates a query where all words must
    // be contained in the document.
    return window.GuideSearch.lunrIndex.search('+' + words.join(' +'));
  }

  var showSpinner = function() {
    var spinner = searchContainer().querySelector('.search-spinner');
    spinner.style.display = 'block';
  }

  var hideSpinner = function() {
    var spinner = searchContainer().querySelector('.search-spinner');
    spinner.style.display = 'none';
  }

  var findDocument = function(ref) {
    return lunrDocuments.find(function(doc) {
      return parseInt(ref, 10) === doc.id;
    });
  }

  var highlight = function(doc, result) {
    // Try to display the 60 preceding and 60 following characters of
    // the document for context. `result` contains the starting
    // position and length of the match.
    var CONTEXT = 60;
    var terms = result.matchData.metadata;

    var termName = Object.keys(terms)[0];
    var matchingFields = terms[termName];

    var fieldName = Object.keys(matchingFields)[0];
    var matchingField = matchingFields[fieldName];

    var position = matchingField.position[0];
    var startPos = position[0];
    var len = position[1];
    var extract = doc[fieldName].substring(startPos - CONTEXT, startPos + len + CONTEXT);
    var offset = startPos >= CONTEXT ? CONTEXT : startPos;
    var highlighted = insertAt(extract, '</span>', offset + len);
    highlighted = insertAt(highlighted, '<span class="underline">', offset);
    if(startPos > CONTEXT) {
      highlighted = '...' + highlighted;
    }
    return highlighted;
  }

  var insertAt = function(str1, str2, at) {
    return str1.slice(0, at) + str2 + str1.slice(at);
  }
}).call(this);

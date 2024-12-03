# frozen_string_literal: true

require "useragent"

module PatchedUserAgent
  # Refining UserAgent to handle Google PageSpeed Insights
  # Until fix in this PR is merged and gem is updated https://github.com/gshutler/useragent/pull/67
  refine UserAgent do
    def bot?
      # Google PageSpeed Insights adds "Chrome-Lighthouse" to the user agent
      # https://stackoverflow.com/questions/16403295/what-is-the-name-of-the-google-pagespeed-user-agent
      if detect_product("Chrome-Lighthouse")
        true
      else
        original_bot?
      end
    end
  
    private
      alias_method :original_bot?, :bot?
  end
end

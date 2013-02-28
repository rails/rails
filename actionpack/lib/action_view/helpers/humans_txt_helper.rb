module ActionView
  # = Action View HumanTxt Helper
  module Helpers
    module HumansTxtHelper
      # Returns a link tag complying with humanstxt standard
      # More info:
      # http://humanstxt.org
      #   <head>
      #     <%= humans_txt_tag %>
      #   </head>
      def humans_txt_tag
        tag('link', :rel => 'author', :href => '/humans.txt').html_safe
      end
    end
  end
end

require 'action_view/body_parts/threaded'
require 'open-uri'

module ActionView
  module BodyParts
    class OpenUri < Threaded
      def initialize(url)
        url = URI::Generic === url ? url : URI.parse(url)
        super(true) { |parts| parts << url.read }
      end
    end
  end
end

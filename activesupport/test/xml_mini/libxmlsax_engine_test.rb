begin
  require "libxml"
rescue LoadError
  # Skip libxml tests
else
  require "abstract_unit"
  require "active_support/xml_mini"
  require "active_support/core_ext/hash/conversions"
  require_relative "./common"

  class LibXMLSAXEngineTest < ActiveSupport::TestCase
    include CommonXMLMiniAdapterTest

    private

      def engine
        "LibXMLSAX"
      end

      def expansion_attack_error
        LibXML::XML::Error
      end
  end
end

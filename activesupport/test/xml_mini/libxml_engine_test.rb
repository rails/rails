begin
  require "libxml"
rescue LoadError
  # Skip libxml tests
else
  require "abstract_unit"
  require "active_support/xml_mini"
  require "active_support/core_ext/hash/conversions"
  require_relative "./common"

  class LibxmlEngineTest < ActiveSupport::TestCase
    include CommonXMLMiniAdapterTest

    def setup
      super
      LibXML::XML::Error.set_handler(&lambda { |error| }) #silence libxml, exceptions will do
    end

    private

      def engine
        "LibXML"
      end

      def expansion_attack_error
        LibXML::XML::Error
      end
  end
end

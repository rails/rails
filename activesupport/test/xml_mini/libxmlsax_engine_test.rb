require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_gem("libxml") do
  class LibXMLSAXEngineTest < XMLMiniEngineTest
    private
      def engine
        "LibXMLSAX"
      end

      def expansion_attack_error
        LibXML::XML::Error
      end
  end
end

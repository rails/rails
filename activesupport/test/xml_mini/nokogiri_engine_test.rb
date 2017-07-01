require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_gem("nokogiri") do
  class NokogiriEngineTest < XMLMiniEngineTest
    private
      def engine
        "Nokogiri"
      end

      def expansion_attack_error
        Nokogiri::XML::SyntaxError
      end
  end
end

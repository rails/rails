require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_gem("nokogiri") do
  class NokogiriSAXEngineTest < XMLMiniEngineTest
    private
      def engine
        "NokogiriSAX"
      end

      def expansion_attack_error
        RuntimeError
      end
  end
end

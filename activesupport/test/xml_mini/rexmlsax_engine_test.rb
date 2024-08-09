# frozen_string_literal: true

require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_gem("rexml") do
  class REXMLSAXEngineTest < XMLMiniEngineTest
    private
      def engine
        "REXMLSAX"
      end

      def expansion_attack_error
        RuntimeError
      end
  end
end

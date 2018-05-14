# frozen_string_literal: true

require_relative "xml_mini_engine_test"

XMLMiniEngineTest.run_with_gem("libxml") do
  class LibxmlEngineTest < XMLMiniEngineTest
    def setup
      super
      LibXML::XML::Error.set_handler(&lambda { |error| }) # silence libxml, exceptions will do
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

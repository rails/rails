begin
  require "nokogiri"
rescue LoadError
  # Skip nokogiri tests
else
  require "abstract_unit"
  require "active_support/xml_mini"
  require "active_support/core_ext/hash/conversions"
  require_relative "./common"

  class NokogiriSAXEngineTest < ActiveSupport::TestCase
    include CommonXMLMiniAdapterTest

    private

      def engine
        "NokogiriSAX"
      end

      def expansion_attack_error
        RuntimeError
      end
  end
end

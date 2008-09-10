require 'rexml/document'
require 'rexml/entity'

# Fixes the rexml vulnerability disclosed at:
# http://www.ruby-lang.org/en/news/2008/08/23/dos-vulnerability-in-rexml/
# This fix is identical to rexml-expansion-fix version 1.0.1

# Earlier versions of rexml defined REXML::Version, newer ones REXML::VERSION
unless (defined?(REXML::VERSION) ? REXML::VERSION : REXML::Version) > "3.1.7.2"
  module REXML
    class Entity < Child
      undef_method :unnormalized
      def unnormalized
        document.record_entity_expansion! if document
        v = value()
        return nil if v.nil?
        @unnormalized = Text::unnormalize(v, parent)
        @unnormalized
      end
    end
    class Document < Element
      @@entity_expansion_limit = 10_000
      def self.entity_expansion_limit= val
        @@entity_expansion_limit = val
      end

      def record_entity_expansion!
        @number_of_expansions ||= 0
        @number_of_expansions += 1
        if @number_of_expansions > @@entity_expansion_limit
          raise "Number of entity expansions exceeded, processing aborted."
        end
      end
    end
  end
end
require 'active_support/core_ext/kernel/reporting'

# Fixes the rexml vulnerability disclosed at:
# http://www.ruby-lang.org/en/news/2008/08/23/dos-vulnerability-in-rexml/
# This fix is identical to rexml-expansion-fix version 1.0.1.
#
# We still need to distribute this fix because albeit the REXML
# in recent 1.8.7s is patched, it wasn't in early patchlevels.
require 'rexml/rexml'

# Earlier versions of rexml defined REXML::Version, newer ones REXML::VERSION
unless (defined?(REXML::VERSION) ? REXML::VERSION : REXML::Version) > "3.1.7.2"
  silence_warnings { require 'rexml/document' }

  # REXML in 1.8.7 has the patch but early patchlevels didn't update Version from 3.1.7.2.
  unless REXML::Document.respond_to?(:entity_expansion_limit=)
    silence_warnings { require 'rexml/entity' }

    module REXML #:nodoc:
      class Entity < Child #:nodoc:
        undef_method :unnormalized
        def unnormalized
          document.record_entity_expansion! if document
          v = value()
          return nil if v.nil?
          @unnormalized = Text::unnormalize(v, parent)
          @unnormalized
        end
      end
      class Document < Element #:nodoc:
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
end

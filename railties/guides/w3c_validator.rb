# ---------------------------------------------------------------------------
#
# This script validates the generated guides against the W3C Validator.
#
# Guides are taken from the output directory, from where all .html files are
# submitted to the validator.
#
# This script is prepared to be launched from the railties directory as a rake task:
#
# rake validate_guides
#
# If nothing is specified, all files will be validated, but you can check just
# some of them using this environment variable:
#
#   ONLY
#     Use ONLY if you want to validate only one or a set of guides. Prefixes are
#     enough:
#
#       # validates only association_basics.html
#       ONLY=assoc rake validate_guides
#
#     Separate many using commas:
#
#       # validates only 
#       ONLY=assoc,migrations rake validate_guides
#
# ---------------------------------------------------------------------------

require 'rubygems'
require 'w3c_validators'
include W3CValidators

module RailsGuides
  class Validator
    
    def validate
      validator = MarkupValidator.new

      guides_to_validate.each do |f|  
        puts "Validating #{f}"
        results = validator.validate_file(f)

        if !results.validity
          puts "#{f} FAILED W3C validation with #{results.errors.size} error(s):"
          results.errors.each do |error|
            puts error.to_s
          end
        end
      end
    end
    
    private
    def guides_to_validate
      guides = Dir["./guides/output/*.html"]
      ENV.key?('ONLY') ? select_only(guides) : guides
    end

    def select_only(guides)
      prefixes = ENV['ONLY'].split(",").map(&:strip)
      guides.select do |guide|
        prefixes.any? {|p| guide.start_with?("./guides/output/#{p}")}
      end
    end
  end
end

RailsGuides::Validator.new.validate
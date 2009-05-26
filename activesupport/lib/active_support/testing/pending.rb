# Some code from jeremymcanally's "pending"
# http://github.com/jeremymcanally/pending/tree/master

module ActiveSupport
  module Testing
    module Pending

      unless defined?(Spec)

        @@pending_cases = []
        @@at_exit = false

        def pending(description = "", &block)
          if description.is_a?(Symbol)
            is_pending = $tags[description]
            return block.call unless is_pending
          end

          if block_given?
            failed = false

            begin
              block.call
            rescue Exception
              failed = true
            end

            flunk("<#{description}> did not fail.") unless failed 
          end

          caller[0] =~ (/(.*):(.*):in `(.*)'/)
          @@pending_cases << "#{$3} at #{$1}, line #{$2}"
          print "P"
      
          @@at_exit ||= begin
            at_exit do
              puts "\nPending Cases:"
              @@pending_cases.each do |test_case|
                puts test_case
              end
            end
          end
        end
      end
      
    end
  end
end
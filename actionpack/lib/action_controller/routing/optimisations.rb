module ActionController
  module Routing
    # Much of the slow performance from routes comes from the 
    # complexity of expiry, :requirements matching, defaults providing
    # and figuring out which url pattern to use.  With named routes 
    # we can avoid the expense of finding the right route.  So if 
    # they've provided the right number of arguments, and have no
    # :requirements, we can just build up a string and return it.
    # 
    # To support building optimisations for other common cases, the 
    # generation code is separated into several classes 
    module Optimisation
      def generate_optimisation_block(route, kind)
        return "" unless route.optimise?
        OPTIMISERS.inject("") do |memo, klazz|
          memo << klazz.new(route, kind).source_code
          memo
        end
      end

      class Optimiser
        attr_reader :route, :kind
        def initialize(route, kind)
          @route = route
          @kind  = kind
        end

        def guard_condition
          'false'
        end

        def generation_code
          'nil'
        end

        def source_code
          if applicable?
            "return #{generation_code} if #{guard_condition}\n"
          else
            "\n"
          end
        end

        # Temporarily disabled :url optimisation pending proper solution to 
        # Issues around request.host etc.
        def applicable?
          true
        end
      end

      # Given a route:
      # map.person '/people/:id'
      #
      # If the user calls person_url(@person), we can simply
      # return a string like "/people/#{@person.to_param}" 
      # rather than triggering the expensive logic in url_for
      class PositionalArguments < Optimiser
        def guard_condition
          number_of_arguments = route.segment_keys.size
          # if they're using foo_url(:id=>2) it's one 
          # argument, but we don't want to generate /foos/id2
          if number_of_arguments == 1
            "defined?(request) && request && args.size == 1 && !args.first.is_a?(Hash)"
          else
            "defined?(request) && request && args.size == #{number_of_arguments}"
          end
        end

        def generation_code
          elements = []
          idx = 0

          if kind == :url
            elements << '#{request.protocol}'
            elements << '#{request.host_with_port}'
          end

          elements << '#{request.relative_url_root if request.relative_url_root}'

          # The last entry in route.segments appears to # *always* be a
          # 'divider segment' for '/' but we have assertions to ensure that
          # we don't include the trailing slashes, so skip them.
          (route.segments.size == 1 ? route.segments : route.segments[0..-2]).each do |segment|
            if segment.is_a?(DynamicSegment)
              elements << segment.interpolation_chunk("args[#{idx}].to_param")
              idx += 1
            else
              elements << segment.interpolation_chunk
            end
          end
          %("#{elements * ''}")
        end
      end

      # This case is mostly the same as the positional arguments case
      # above, but it supports additional query parameters as the last 
      # argument
      class PositionalArgumentsWithAdditionalParams < PositionalArguments
        def guard_condition
          "defined?(request) && request && args.size == #{route.segment_keys.size + 1} && !args.last.has_key?(:anchor) && !args.last.has_key?(:port) && !args.last.has_key?(:host)"
        end

        # This case uses almost the same code as positional arguments, 
        # but add an args.last.to_query on the end
        def generation_code
          super.insert(-2, '?#{args.last.to_query}')
        end

        # To avoid generating http://localhost/?host=foo.example.com we
        # can't use this optimisation on routes without any segments
        def applicable?
          super && route.segment_keys.size > 0 
        end
      end

      OPTIMISERS = [PositionalArguments, PositionalArgumentsWithAdditionalParams]
    end
  end
end

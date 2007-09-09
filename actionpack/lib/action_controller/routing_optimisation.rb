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
    # generation code is seperated into several classes 
    module Optimisation
      def generate_optimisation_block(route, kind)
        return "" unless route.optimise?
        OPTIMISERS.inject("") do |memo, klazz|
          optimiser = klazz.new(route, kind)
          memo << "return #{optimiser.generation_code} if #{optimiser.guard_condition}\n"
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
            "args.size == 1 && !args.first.is_a?(Hash)"
          else
            "args.size == #{number_of_arguments}"
          end
        end

        def generation_code
          elements = []
          idx = 0


          if kind == :url
            elements << '#{request.protocol}'
            elements << '#{request.host_with_port}'
          end

          # The last entry in route.segments appears to
          # *always* be a 'divider segment' for '/'
          # but we have assertions to ensure that we don't
          # include the trailing slashes, so skip them
          route.segments[0..-2].each do |segment|
            if segment.is_a?(DynamicSegment)
              elements << "\#{URI.escape(args[#{idx}].to_param, ActionController::Routing::Segment::UNSAFE_PCHAR)}"
              idx += 1
            else
              elements << segment.to_s
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
          "args.size == #{route.segment_keys.size + 1}"
        end

        # This case uses almost the Use the same code as positional arguments, 
        # but add an args.last.to_query on the end
        def generation_code
          super.insert(-2, '?#{args.last.to_query}')
        end
      end

      OPTIMISERS = [PositionalArguments, PositionalArgumentsWithAdditionalParams]
    end
  end
end
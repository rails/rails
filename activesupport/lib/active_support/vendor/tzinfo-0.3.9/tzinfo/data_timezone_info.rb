#--
# Copyright (c) 2006 Philip Ross
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++

require 'tzinfo/time_or_datetime'
require 'tzinfo/timezone_info'
require 'tzinfo/timezone_offset_info'
require 'tzinfo/timezone_period'
require 'tzinfo/timezone_transition_info'

module TZInfo
  # Thrown if no offsets have been defined when calling period_for_utc or
  # periods_for_local. Indicates an error in the timezone data.
  class NoOffsetsDefined < StandardError
  end
    
  # Represents a (non-linked) timezone defined in a data module.
  class DataTimezoneInfo < TimezoneInfo #:nodoc:
            
    # Constructs a new TimezoneInfo with its identifier.
    def initialize(identifier)   
      super(identifier)
      @offsets = {}
      @transitions = []
      @previous_offset = nil
      @transitions_index = nil
    end
 
    # Defines a offset. The id uniquely identifies this offset within the
    # timezone. utc_offset and std_offset define the offset in seconds of 
    # standard time from UTC and daylight savings from standard time 
    # respectively. abbreviation describes the timezone offset (e.g. GMT, BST,
    # EST or EDT).
    #
    # The first offset to be defined is treated as the offset that applies
    # until the first transition. This will usually be in Local Mean Time (LMT).
    #
    # ArgumentError will be raised if the id is already defined.
    def offset(id, utc_offset, std_offset, abbreviation)
      raise ArgumentError, 'Offset already defined' if @offsets.has_key?(id)
      
      offset = TimezoneOffsetInfo.new(utc_offset, std_offset, abbreviation)
      @offsets[id] = offset
      @previous_offset = offset unless @previous_offset
    end
    
    # Defines a transition. Transitions must be defined in chronological order.
    # ArgumentError will be raised if a transition is added out of order.
    # offset_id refers to an id defined with offset. ArgumentError will be 
    # raised if the offset_id cannot be found. numerator_or_time and
    # denomiator specify the time the transition occurs as. See 
    # TimezoneTransitionInfo for more detail about specifying times.
    def transition(year, month, offset_id, numerator_or_time, denominator = nil)
      offset = @offsets[offset_id]      
      raise ArgumentError, 'Offset not found' unless offset
            
      if @transitions_index
        if year < @last_year || (year == @last_year && month < @last_month)
          raise ArgumentError, 'Transitions must be increasing date order'
        end
        
        # Record the position of the first transition with this index.
        index = transition_index(year, month)
        @transitions_index[index] ||= @transitions.length
                
        # Fill in any gaps       
        (index - 1).downto(0) do |i|
          break if @transitions_index[i]
          @transitions_index[i] = @transitions.length
        end
      else
        @transitions_index = [@transitions.length]
        @start_year = year
        @start_month = month        
      end
      
      @transitions << TimezoneTransitionInfo.new(offset, @previous_offset, 
        numerator_or_time, denominator)
      @last_year = year
      @last_month = month             
      @previous_offset = offset
    end           
    
    # Returns the TimezonePeriod for the given UTC time.
    # Raises NoOffsetsDefined if no offsets have been defined.
    def period_for_utc(utc)
      unless @transitions.empty?
        utc = TimeOrDateTime.wrap(utc)               
        index = transition_index(utc.year, utc.mon)
        
        start_transition = nil
        start = transition_before_end(index)
        if start
          start.downto(0) do |i|
            if @transitions[i].at <= utc
              start_transition = @transitions[i]
              break
            end
          end
        end
        
        end_transition = nil
        start = transition_after_start(index)      
        if start
          start.upto(@transitions.length - 1) do |i|
            if @transitions[i].at > utc
              end_transition = @transitions[i]
              break
            end
          end
        end
               
        if start_transition || end_transition
          TimezonePeriod.new(start_transition, end_transition)
        else
          # Won't happen since there are transitions. Must always find one
          # transition that is either >= or < the specified time.
          raise 'No transitions found in search'
        end        
      else
        raise NoOffsetsDefined, 'No offsets have been defined' unless @previous_offset        
        TimezonePeriod.new(nil, nil, @previous_offset)
      end
    end
    
    # Returns the set of TimezonePeriods for the given local time as an array.    
    # Results returned are ordered by increasing UTC start date.
    # Returns an empty array if no periods are found for the given time.
    # Raises NoOffsetsDefined if no offsets have been defined.    
    def periods_for_local(local)
      unless @transitions.empty?
        local = TimeOrDateTime.wrap(local)
        index = transition_index(local.year, local.mon)
        
        result = []
       
        start_index = transition_after_start(index - 1)       
        if start_index && @transitions[start_index].local_end > local           
          if start_index > 0
            if @transitions[start_index - 1].local_start <= local 
              result << TimezonePeriod.new(@transitions[start_index - 1], @transitions[start_index])
            end
          else
            result << TimezonePeriod.new(nil, @transitions[start_index])
          end
        end
        
        end_index = transition_before_end(index + 1)
        
        if end_index        
          start_index = end_index unless start_index
          
          start_index.upto(transition_before_end(index + 1)) do |i|
            if @transitions[i].local_start <= local
              if i + 1 < @transitions.length
                if @transitions[i + 1].local_end > local
                  result << TimezonePeriod.new(@transitions[i], @transitions[i + 1])
                end
              else
                result << TimezonePeriod.new(@transitions[i], nil)
              end
            end
          end
        end
        
        result
      else
        raise NoOffsetsDefined, 'No offsets have been defined' unless @previous_offset
        [TimezonePeriod.new(nil, nil, @previous_offset)]
      end
    end
    
    private
      # Returns the index into the @transitions_index array for a given year 
      # and month.
      def transition_index(year, month)
        index = (year - @start_year) * 2
        index += 1 if month > 6
        index -= 1 if @start_month > 6
        index
      end
      
      # Returns the index into @transitions of the first transition that occurs
      # on or after the start of the given index into @transitions_index.
      # Returns nil if there are no such transitions.
      def transition_after_start(index)
        if index >= @transitions_index.length
          nil
        else
          index = 0 if index < 0
          @transitions_index[index]
        end
      end
      
      # Returns the index into @transitions of the first transition that occurs
      # before the end of the given index into @transitions_index.
      # Returns nil if there are no such transitions.
      def transition_before_end(index)
        index = index + 1
        
        if index <= 0
          nil
        elsif index >= @transitions_index.length          
          @transitions.length - 1
        else      
          @transitions_index[index] - 1          
        end
      end            
  end
end

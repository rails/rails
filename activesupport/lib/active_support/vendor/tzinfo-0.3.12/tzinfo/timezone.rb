#--
# Copyright (c) 2005-2006 Philip Ross
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

require 'date'
# require 'tzinfo/country'
require 'tzinfo/time_or_datetime'
require 'tzinfo/timezone_period'

module TZInfo
  # Indicate a specified time in a local timezone has more than one
  # possible time in UTC. This happens when switching from daylight savings time 
  # to normal time where the clocks are rolled back. Thrown by period_for_local
  # and local_to_utc when using an ambiguous time and not specifying any 
  # means to resolve the ambiguity.
  class AmbiguousTime < StandardError
  end
  
  # Thrown to indicate that no TimezonePeriod matching a given time could be found.
  class PeriodNotFound < StandardError
  end
  
  # Thrown by Timezone#get if the identifier given is not valid.
  class InvalidTimezoneIdentifier < StandardError
  end
  
  # Thrown if an attempt is made to use a timezone created with Timezone.new(nil).
  class UnknownTimezone < StandardError
  end
  
  # Timezone is the base class of all timezones. It provides a factory method
  # get to access timezones by identifier. Once a specific Timezone has been
  # retrieved, DateTimes, Times and timestamps can be converted between the UTC 
  # and the local time for the zone. For example:
  #
  #   tz = TZInfo::Timezone.get('America/New_York')
  #   puts tz.utc_to_local(DateTime.new(2005,8,29,15,35,0)).to_s
  #   puts tz.local_to_utc(Time.utc(2005,8,29,11,35,0)).to_s
  #   puts tz.utc_to_local(1125315300).to_s
  #
  # Each time conversion method returns an object of the same type it was 
  # passed.
  #
  # The timezone information all comes from the tz database
  # (see http://www.twinsun.com/tz/tz-link.htm)
  class Timezone
    include Comparable
    
    # Cache of loaded zones by identifier to avoid using require if a zone
    # has already been loaded.
    @@loaded_zones = {}
    
    # Whether the timezones index has been loaded yet.
    @@index_loaded = false
    
    # Returns a timezone by its identifier (e.g. "Europe/London", 
    # "America/Chicago" or "UTC").
    #
    # Raises InvalidTimezoneIdentifier if the timezone couldn't be found.
    def self.get(identifier)
      instance = @@loaded_zones[identifier]
      unless instance  
        raise InvalidTimezoneIdentifier, 'Invalid identifier' if identifier !~ /^[A-z0-9\+\-_]+(\/[A-z0-9\+\-_]+)*$/
        identifier = identifier.gsub(/-/, '__m__').gsub(/\+/, '__p__')
        begin
          # Use a temporary variable to avoid an rdoc warning
          file = "tzinfo/definitions/#{identifier}"
          require file
          
          m = Definitions
          identifier.split(/\//).each {|part|
            m = m.const_get(part)
          }
          
          info = m.get
          
          # Could make Timezone subclasses register an interest in an info
          # type. Since there are currently only two however, there isn't
          # much point.
          if info.kind_of?(DataTimezoneInfo)
            instance = DataTimezone.new(info)
          elsif info.kind_of?(LinkedTimezoneInfo)
            instance = LinkedTimezone.new(info)
          else
            raise InvalidTimezoneIdentifier, "No handler for info type #{info.class}"
          end
          
          @@loaded_zones[instance.identifier] = instance         
        rescue LoadError, NameError => e
          raise InvalidTimezoneIdentifier, e.message
        end
      end
      
      instance
    end
    
    # Returns a proxy for the Timezone with the given identifier. The proxy
    # will cause the real timezone to be loaded when an attempt is made to 
    # find a period or convert a time. get_proxy will not validate the 
    # identifier. If an invalid identifier is specified, no exception will be 
    # raised until the proxy is used. 
    def self.get_proxy(identifier)
      TimezoneProxy.new(identifier)
    end
    
    # If identifier is nil calls super(), otherwise calls get. An identfier 
    # should always be passed in when called externally.
    def self.new(identifier = nil)
      if identifier        
        get(identifier)
      else
        super()
      end
    end
    
    # Returns an array containing all the available Timezones.
    #
    # Returns TimezoneProxy objects to avoid the overhead of loading Timezone
    # definitions until a conversion is actually required.
    def self.all
      get_proxies(all_identifiers)
    end
    
    # Returns an array containing the identifiers of all the available 
    # Timezones.
    def self.all_identifiers
      load_index
      Indexes::Timezones.timezones
    end
    
    # Returns an array containing all the available Timezones that are based
    # on data (are not links to other Timezones).
    #
    # Returns TimezoneProxy objects to avoid the overhead of loading Timezone
    # definitions until a conversion is actually required.
    def self.all_data_zones
      get_proxies(all_data_zone_identifiers)
    end
    
    # Returns an array containing the identifiers of all the available 
    # Timezones that are based on data (are not links to other Timezones)..
    def self.all_data_zone_identifiers
      load_index
      Indexes::Timezones.data_timezones
    end
    
    # Returns an array containing all the available Timezones that are links
    # to other Timezones.
    #
    # Returns TimezoneProxy objects to avoid the overhead of loading Timezone
    # definitions until a conversion is actually required.
    def self.all_linked_zones
      get_proxies(all_linked_zone_identifiers)      
    end
    
    # Returns an array containing the identifiers of all the available 
    # Timezones that are links to other Timezones.
    def self.all_linked_zone_identifiers
      load_index
      Indexes::Timezones.linked_timezones
    end
    
    # Returns all the Timezones defined for all Countries. This is not the
    # complete set of Timezones as some are not country specific (e.g. 
    # 'Etc/GMT').
    # 
    # Returns TimezoneProxy objects to avoid the overhead of loading Timezone
    # definitions until a conversion is actually required.        
    def self.all_country_zones
      Country.all_codes.inject([]) {|zones,country|
        zones += Country.get(country).zones
      }
    end
    
    # Returns all the zone identifiers defined for all Countries. This is not the
    # complete set of zone identifiers as some are not country specific (e.g. 
    # 'Etc/GMT'). You can obtain a Timezone instance for a given identifier
    # with the get method.
    def self.all_country_zone_identifiers
      Country.all_codes.inject([]) {|zones,country|
        zones += Country.get(country).zone_identifiers
      }
    end
    
    # Returns all US Timezone instances. A shortcut for 
    # TZInfo::Country.get('US').zones.
    #
    # Returns TimezoneProxy objects to avoid the overhead of loading Timezone
    # definitions until a conversion is actually required.
    def self.us_zones
      Country.get('US').zones
    end
    
    # Returns all US zone identifiers. A shortcut for 
    # TZInfo::Country.get('US').zone_identifiers.
    def self.us_zone_identifiers
      Country.get('US').zone_identifiers
    end
    
    # The identifier of the timezone, e.g. "Europe/Paris".
    def identifier
      raise UnknownTimezone, 'TZInfo::Timezone constructed directly'
    end
    
    # An alias for identifier.
    def name
      # Don't use alias, as identifier gets overridden.
      identifier
    end
    
    # Returns a friendlier version of the identifier.
    def to_s
      friendly_identifier
    end
    
    # Returns internal object state as a programmer-readable string.
    def inspect
      "#<#{self.class}: #{identifier}>"
    end
    
    # Returns a friendlier version of the identifier. Set skip_first_part to 
    # omit the first part of the identifier (typically a region name) where
    # there is more than one part.
    #
    # For example:
    #
    #   Timezone.get('Europe/Paris').friendly_identifier(false)          #=> "Europe - Paris"
    #   Timezone.get('Europe/Paris').friendly_identifier(true)           #=> "Paris"
    #   Timezone.get('America/Indiana/Knox').friendly_identifier(false)  #=> "America - Knox, Indiana"
    #   Timezone.get('America/Indiana/Knox').friendly_identifier(true)   #=> "Knox, Indiana"           
    def friendly_identifier(skip_first_part = false)
      parts = identifier.split('/')
      if parts.empty?
        # shouldn't happen
        identifier
      elsif parts.length == 1        
        parts[0]
      else
        if skip_first_part
          result = ''
        else
          result = parts[0] + ' - '
        end
        
        parts[1, parts.length - 1].reverse_each {|part|
          part.gsub!(/_/, ' ')
          
          if part.index(/[a-z]/)
            # Missing a space if a lower case followed by an upper case and the
            # name isn't McXxxx.
            part.gsub!(/([^M][a-z])([A-Z])/, '\1 \2')
            part.gsub!(/([M][a-bd-z])([A-Z])/, '\1 \2')
            
            # Missing an apostrophe if two consecutive upper case characters.
            part.gsub!(/([A-Z])([A-Z])/, '\1\'\2')
          end
          
          result << part
          result << ', '
        }
        
        result.slice!(result.length - 2, 2)
        result
      end
    end
    
    # Returns the TimezonePeriod for the given UTC time. utc can either be
    # a DateTime, Time or integer timestamp (Time.to_i). Any timezone 
    # information in utc is ignored (it is treated as a UTC time).        
    def period_for_utc(utc)            
      raise UnknownTimezone, 'TZInfo::Timezone constructed directly'      
    end
    
    # Returns the set of TimezonePeriod instances that are valid for the given
    # local time as an array. If you just want a single period, use 
    # period_for_local instead and specify how ambiguities should be resolved.
    # Returns an empty array if no periods are found for the given time.
    def periods_for_local(local)
      raise UnknownTimezone, 'TZInfo::Timezone constructed directly'
    end
    
    # Returns the TimezonePeriod for the given local time. local can either be
    # a DateTime, Time or integer timestamp (Time.to_i). Any timezone 
    # information in local is ignored (it is treated as a time in the current 
    # timezone).
    #
    # Warning: There are local times that have no equivalent UTC times (e.g.
    # in the transition from standard time to daylight savings time). There are
    # also local times that have more than one UTC equivalent (e.g. in the
    # transition from daylight savings time to standard time).
    #
    # In the first case (no equivalent UTC time), a PeriodNotFound exception
    # will be raised.
    #
    # In the second case (more than one equivalent UTC time), an AmbiguousTime
    # exception will be raised unless the optional dst parameter or block
    # handles the ambiguity. 
    #
    # If the ambiguity is due to a transition from daylight savings time to
    # standard time, the dst parameter can be used to select whether the 
    # daylight savings time or local time is used. For example,
    #
    #   Timezone.get('America/New_York').period_for_local(DateTime.new(2004,10,31,1,30,0))
    #
    # would raise an AmbiguousTime exception.
    #
    # Specifying dst=true would the daylight savings period from April to 
    # October 2004. Specifying dst=false would return the standard period
    # from October 2004 to April 2005.
    #
    # If the dst parameter does not resolve the ambiguity, and a block is 
    # specified, it is called. The block must take a single parameter - an
    # array of the periods that need to be resolved. The block can select and
    # return a single period or return nil or an empty array
    # to cause an AmbiguousTime exception to be raised.
    def period_for_local(local, dst = nil)            
      results = periods_for_local(local)
      
      if results.empty?
        raise PeriodNotFound
      elsif results.size < 2
        results.first
      else
        # ambiguous result try to resolve
        
        if !dst.nil?
          matches = results.find_all {|period| period.dst? == dst}
          results = matches if !matches.empty?            
        end
        
        if results.size < 2
          results.first
        else
          # still ambiguous, try the block
                    
          if block_given?
            results = yield results
          end
          
          if results.is_a?(TimezonePeriod)
            results
          elsif results && results.size == 1
            results.first
          else          
            raise AmbiguousTime, "#{local} is an ambiguous local time."
          end
        end
      end      
    end
    
    # Converts a time in UTC to the local timezone. utc can either be
    # a DateTime, Time or timestamp (Time.to_i). The returned time has the same
    # type as utc. Any timezone information in utc is ignored (it is treated as 
    # a UTC time).
    def utc_to_local(utc)
      TimeOrDateTime.wrap(utc) {|wrapped|
        period_for_utc(wrapped).to_local(wrapped)
      }
    end
    
    # Converts a time in the local timezone to UTC. local can either be
    # a DateTime, Time or timestamp (Time.to_i). The returned time has the same
    # type as local. Any timezone information in local is ignored (it is treated
    # as a local time).
    #
    # Warning: There are local times that have no equivalent UTC times (e.g.
    # in the transition from standard time to daylight savings time). There are
    # also local times that have more than one UTC equivalent (e.g. in the
    # transition from daylight savings time to standard time).
    #
    # In the first case (no equivalent UTC time), a PeriodNotFound exception
    # will be raised.
    #
    # In the second case (more than one equivalent UTC time), an AmbiguousTime
    # exception will be raised unless the optional dst parameter or block
    # handles the ambiguity. 
    #
    # If the ambiguity is due to a transition from daylight savings time to
    # standard time, the dst parameter can be used to select whether the 
    # daylight savings time or local time is used. For example,
    #
    #   Timezone.get('America/New_York').local_to_utc(DateTime.new(2004,10,31,1,30,0))
    #
    # would raise an AmbiguousTime exception.
    #
    # Specifying dst=true would return 2004-10-31 5:30:00. Specifying dst=false
    # would return 2004-10-31 6:30:00.
    #
    # If the dst parameter does not resolve the ambiguity, and a block is 
    # specified, it is called. The block must take a single parameter - an
    # array of the periods that need to be resolved. The block can return a
    # single period to use to convert the time or return nil or an empty array
    # to cause an AmbiguousTime exception to be raised.
    def local_to_utc(local, dst = nil)
      TimeOrDateTime.wrap(local) {|wrapped|
        if block_given?
          period = period_for_local(wrapped, dst) {|periods| yield periods }
        else
          period = period_for_local(wrapped, dst)
        end
        
        period.to_utc(wrapped)
      }
    end
    
    # Returns the current time in the timezone as a Time.
    def now
      utc_to_local(Time.now.utc)
    end
    
    # Returns the TimezonePeriod for the current time. 
    def current_period
      period_for_utc(Time.now.utc)
    end
    
    # Returns the current Time and TimezonePeriod as an array. The first element
    # is the time, the second element is the period.
    def current_period_and_time
      utc = Time.now.utc
      period = period_for_utc(utc)
      [period.to_local(utc), period]
    end
    
    alias :current_time_and_period :current_period_and_time

    # Converts a time in UTC to local time and returns it as a string 
    # according to the given format. The formatting is identical to 
    # Time.strftime and DateTime.strftime, except %Z is replaced with the
    # timezone abbreviation for the specified time (for example, EST or EDT).        
    def strftime(format, utc = Time.now.utc)      
      period = period_for_utc(utc)
      local = period.to_local(utc)      
      local = Time.at(local).utc unless local.kind_of?(Time) || local.kind_of?(DateTime)
      abbreviation = period.abbreviation.to_s.gsub(/%/, '%%')
      
      format = format.gsub(/(.?)%Z/) do
        if $1 == '%'
          # return %%Z so the real strftime treats it as a literal %Z too
          '%%Z'
        else
          "#$1#{abbreviation}"
        end
      end
      
      local.strftime(format)
    end
    
    # Compares two Timezones based on their identifier. Returns -1 if tz is less
    # than self, 0 if tz is equal to self and +1 if tz is greater than self.
    def <=>(tz)
      identifier <=> tz.identifier
    end
    
    # Returns true if and only if the identifier of tz is equal to the 
    # identifier of this Timezone.
    def eql?(tz)
      self == tz
    end
    
    # Returns a hash of this Timezone.
    def hash
      identifier.hash
    end
    
    # Dumps this Timezone for marshalling.
    def _dump(limit)
      identifier
    end
    
    # Loads a marshalled Timezone.
    def self._load(data)
      Timezone.get(data)
    end
    
    private
      # Loads in the index of timezones if it hasn't already been loaded.
      def self.load_index
        unless @@index_loaded
          require 'tzinfo/indexes/timezones'
          @@index_loaded = true
        end        
      end
      
      # Returns an array of proxies corresponding to the given array of 
      # identifiers.
      def self.get_proxies(identifiers)
        identifiers.collect {|identifier| get_proxy(identifier)}
      end
  end        
end

# encoding: us-ascii
######################## BEGIN LICENSE BLOCK ########################
# The Original Code is Mozilla Universal charset detector code.
#
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 2001
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Jeff Hodges - port to Ruby
#   Mark Pilgrim - port to Python
#   Shy Shalom - original C code
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301  USA
######################### END LICENSE BLOCK #########################

module CharDet
  MINIMUM_THRESHOLD = 0.20
  EPureAscii = 0
  EEscAscii = 1
  EHighbyte = 2

  class UniversalDetector
    attr_accessor :result
    def initialize
      @_highBitDetector = /[\x80-\xFF]/
      @_escDetector = /(\033|\~\{)/
      @_mEscCharSetProber = nil
      @_mCharSetProbers = []
      reset()
    end

    def reset
      @result = {'encoding' => nil, 'confidence' => 0.0}
      @done = false
      @_mStart = true
      @_mGotData = false
      @_mInputState = EPureAscii
      @_mLastChar = ''
      if @_mEscCharSetProber
        @_mEscCharSetProber.reset()
      end
      for prober in @_mCharSetProbers
        prober.reset()
      end
    end

    def feed(aBuf)
      return if @done

      aLen = aBuf.length
      return if not aLen

      if not @_mGotData
        # If the data starts with BOM, we know it is UTF
        if aBuf[0...3] == "\xEF\xBB\xBF"
          # EF BB BF  UTF-8 with BOM
          @result = {'encoding' => "UTF-8", 'confidence' => 1.0}
        elsif aBuf[0...4] == "\xFF\xFE\x00\x00"
          # FF FE 00 00  UTF-32, little-endian BOM
          @result = {'encoding' => "UTF-32LE", 'confidence' => 1.0}
        elsif aBuf[0...4] == "\x00\x00\xFE\xFF"
          # 00 00 FE FF  UTF-32, big-endian BOM
          @result = {'encoding' => "UTF-32BE", 'confidence' => 1.0}
        elsif aBuf[0...4] == "\xFE\xFF\x00\x00"
          # FE FF 00 00  UCS-4, unusual octet order BOM (3412)
          @result = {'encoding' => "X-ISO-10646-UCS-4-3412", 'confidence' => 1.0}
        elsif aBuf[0...4] == "\x00\x00\xFF\xFE"
          # 00 00 FF FE  UCS-4, unusual octet order BOM (2143)
          @result = {'encoding' =>  "X-ISO-10646-UCS-4-2143", 'confidence' =>  1.0}
        elsif aBuf[0...2] == "\xFF\xFE"
          # FF FE  UTF-16, little endian BOM
          @result = {'encoding' =>  "UTF-16LE", 'confidence' =>  1.0}
        elsif aBuf[0...2] == "\xFE\xFF"
          # FE FF  UTF-16, big endian BOM
          @result = {'encoding' =>  "UTF-16BE", 'confidence' =>  1.0}
        end
      end

      @_mGotData = true
      if @result['encoding'] and (@result['confidence'] > 0.0)
        @done = true
        return
      end

      if @_mInputState == EPureAscii
        if @_highBitDetector =~ (aBuf)
          @_mInputState = EHighbyte
        elsif (@_mInputState == EPureAscii) and @_escDetector =~ (@_mLastChar + aBuf)
          @_mInputState = EEscAscii
        end
      end

      @_mLastChar = aBuf[-1..-1]
      if @_mInputState == EEscAscii
        if not @_mEscCharSetProber
          @_mEscCharSetProber = EscCharSetProber.new()
        end
        if @_mEscCharSetProber.feed(aBuf) == EFoundIt
          @result = {'encoding' =>  self._mEscCharSetProber.get_charset_name(),
                     'confidence' =>  @_mEscCharSetProber.get_confidence()
          }
          @done = true
        end
      elsif @_mInputState == EHighbyte
        if not @_mCharSetProbers or @_mCharSetProbers.empty?
          @_mCharSetProbers = [MBCSGroupProber.new(), SBCSGroupProber.new(), Latin1Prober.new()]
        end
        for prober in @_mCharSetProbers
          if prober.feed(aBuf) == EFoundIt
            @result = {'encoding' =>  prober.get_charset_name(),
                       'confidence' =>  prober.get_confidence()}
            @done = true
            break
          end
        end
      end

    end

    def close
      return if @done
      if not @_mGotData
        $stderr << "no data received!\n" if $debug
        return
      end
      @done = true

      if @_mInputState == EPureAscii
        @result = {'encoding' => 'ascii', 'confidence' => 1.0}
        return @result
      end

      if @_mInputState == EHighbyte
        confidences = {}
        @_mCharSetProbers.each{ |prober| confidences[prober] = prober.get_confidence }
        maxProber = @_mCharSetProbers.max{ |a,b| confidences[a] <=> confidences[b] }
        if maxProber and maxProber.get_confidence > MINIMUM_THRESHOLD
          @result = {'encoding' =>  maxProber.get_charset_name(),
                     'confidence' =>  maxProber.get_confidence()}
          return @result
        end
      end

      if $debug
        $stderr << "no probers hit minimum threshhold\n" if $debug
        for prober in @_mCharSetProbers[0]._mProbers
          next if not prober
          $stderr << "#{prober.get_charset_name} confidence = #{prober.get_confidence}\n" if $debug
        end
      end
    end
  end
end

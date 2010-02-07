######################## BEGIN LICENSE BLOCK ########################
# The Original Code is mozilla.org code.
#
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 1998
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Jeff Hodges - port to Ruby
#   Mark Pilgrim - port to Python
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
  class SJISProber < MultiByteCharSetProber
    def initialize
      super()
      @_mCodingSM = CodingStateMachine.new(SJISSMModel)
      @_mDistributionAnalyzer = SJISDistributionAnalysis.new()
      @_mContextAnalyzer = SJISContextAnalysis.new()
      reset()
    end

    def reset
      super()
      @_mContextAnalyzer.reset()
    end

    def get_charset_name
      return "SHIFT_JIS"
    end

    def feed(aBuf)
      aLen = aBuf.length
      for i in (0...aLen)
        codingState = @_mCodingSM.next_state(aBuf[i..i])
        if codingState == EError
          $stderr << "#{get_charset_name} prober hit error at byte #{i}\n" if $debug
          @_mState = ENotMe
          break
        elsif codingState == EItsMe
          @_mState = EFoundIt
          break
        elsif codingState == EStart
          charLen = @_mCodingSM.get_current_charlen()
          if i == 0
            @_mLastChar[1] = aBuf[0..0]
            @_mContextAnalyzer.feed(@_mLastChar[2 - charLen..-1], charLen)
            @_mDistributionAnalyzer.feed(@_mLastChar, charLen)
          else
            @_mContextAnalyzer.feed(aBuf[i + 1 - charLen ... i + 3 - charLen], charLen)
            @_mDistributionAnalyzer.feed(aBuf[i - 1 ... i + 1], charLen)
          end
        end
      end

      @_mLastChar[0] = aBuf[aLen - 1.. aLen-1]

      if get_state() == EDetecting
        if @_mContextAnalyzer.got_enough_data() and (get_confidence() > SHORTCUT_THRESHOLD)
          @_mState = EFoundIt
        end
      end

      return get_state()
    end

    def get_confidence
      l = [@_mContextAnalyzer.get_confidence(), @_mDistributionAnalyzer.get_confidence()]
      return l.max
    end
  end
end

######################## BEGIN LICENSE BLOCK ########################
# The Original Code is Mozilla Communicator client code.
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
  class CharSetGroupProber < CharSetProber
    attr_accessor :_mProbers
    def initialize
      super
      @_mActiveNum = 0
      @_mProbers = []
      @_mBestGuessProber = nil
    end

    def reset
      super
      @_mActiveNum = 0

      for prober in @_mProbers:
	if prober
	  prober.reset()
	  prober.active = true
	  @_mActiveNum += 1
	end
      end
      @_mBestGuessProber = nil
    end

    def get_charset_name
      if not @_mBestGuessProber
	get_confidence()
	return nil unless @_mBestGuessProber
	#                self._mBestGuessProber = self._mProbers[0]
      end
      return @_mBestGuessProber.get_charset_name()
    end

    def feed(aBuf)
      for prober in @_mProbers
	next unless prober
	next unless prober.active
	st = prober.feed(aBuf)
	next unless st
	if st == EFoundIt
	  @_mBestGuessProber = prober
	  return get_state()
	elsif st == ENotMe
	  prober.active = false
	  @_mActiveNum -= 1
	  if @_mActiveNum <= 0
	    @_mState = ENotMe
	    return get_state()
	  end
	end
      end
      return get_state()
    end

    def get_confidence()
      st = get_state()
      if st == EFoundIt
	return 0.99
      elsif st == ENotMe
	return 0.01
      end
      bestConf = 0.0
      @_mBestGuessProber = nil
      for prober in @_mProbers
	next unless prober
	unless prober.active
	  $stderr << "#{prober.get_charset_name()} not active\n" if $debug
	  next
	end
	cf = prober.get_confidence()
	$stderr << "#{prober.get_charset_name} confidence = #{cf}\n" if $debug
	if bestConf < cf
	  bestConf = cf
	  @_mBestGuessProber = prober
	end
      end
      return 0.0 unless @_mBestGuessProber
      return bestConf
      #        else:
      #            self._mBestGuessProber = self._mProbers[0]
      #            return self._mBestGuessProber.get_confidence()
    end
  end
end

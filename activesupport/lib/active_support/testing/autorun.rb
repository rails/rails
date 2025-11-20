# frozen_string_literal: true

require "minitest"

##
# I shouldn't need this respond_to check but some tests are running
# sub-process tests in an unbundled environment, causing MT5 to be
# used in some cases. This conditional can probably go after the bump
# is complete? ... but could still fail for developers working w/
# multiple versions installed.
Minitest.load :rails if Minitest.respond_to? :load
Minitest.autorun

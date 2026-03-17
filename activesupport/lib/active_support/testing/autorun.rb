# frozen_string_literal: true

require "minitest"

# This respond_to check handles tests running sub-processes in an
# unbundled environment, which triggers MT5 usage. This conditional may
# be removable after the version bump, though it currently safeguards
# against issues in environments with multiple versions installed.
Minitest.load :rails if Minitest.respond_to? :load
Minitest.autorun

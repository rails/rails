# :markup: markdown
# frozen_string_literal: true

require "minitest"

# This respond_to check handles tests running sub-processes in an
# unbundled environment, which triggers MT5 usage. This conditional may
# be removable after the version bump, though it currently safeguards
# against issues in environments with multiple versions installed.
if Minitest.respond_to? :load
  # Auto-load all installed plugins when using Minitest 6, letting the "rails"
  # plugin override CLI flags last.
  Minitest.load_plugins
  Minitest.extensions.delete("rails")
  Minitest.load :rails
end
Minitest.autorun

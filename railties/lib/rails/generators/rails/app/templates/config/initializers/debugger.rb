# frozen_string_literal: true

return unless Rails.env.local?

begin
  if Rails.env.test? ||
    defined?(Rails::Console) ||
    (defined?(Rake.application.top_level_tasks) && Rake.application.top_level_tasks.any?)

    # Simply require `debug`, and use standard `binding.break`
    require 'debug'
  elsif ENV['RUBY_DEBUG_PORT'] && (defined?(Rails::Server) || ENV['PWD'].include?('.puma-dev'))
    # When ENV['RUBY_DEBUG_PORT'] is set, debug/open_nonstop will start a TCP/IP debugger server
    # on the provided port, which your editor can connect to.
    #
    # https://github.com/ruby/debug/blob/master/lib/debug/open_nonstop.rb
    require 'debug'
    require 'debug/open_nonstop'

    # You can then create breakpoints using your editor's native debugger options
    # (for example, F9 sets a breakpoint in VS Code).
    #
    # - Debug server whether you're running via `rails s` or puma-dev
    # - Debug your tests
    # - Do not debug rake tasks, console sessions, Sidekiq, Tailwind CLI, Vite CLI, etc
    #
    # VS Code users can use the official rdbg extension, to connect:
    # https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg
    #
    # Neovim users can use DAP to connect. This plugin expects RUBY_DEBUG_PORT to be set to 38698.
    # You can then connect to your debugger server with `:lua require("dap").continue()`
    # and then choosing the "debug current file" option.
    # https://github.com/suketa/nvim-dap-ruby
  else
    # No-op. This would be background job processors, Tailwind CLI, Vite CLI, etc.
    # No debugger needed.
  end
rescue LoadError
  # Debug gem is not installed
end

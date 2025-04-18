**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Install Ruby on Rails Guide
===========================

This guide will walk you through installing the Ruby programming language and the Rails framework on your operating system.

While your OS might come with Ruby pre-installed, it's often outdated and can't be upgraded. Using a version manager like [Mise](https://mise.jdx.dev/getting-started.html) allows you to install the latest Ruby version, use a different Ruby version for each app, and easily upgrade to new versions when they're released.

Alternatively, you can use Dev Containers to run Rails without installing Ruby or Rails directly on your machine. Check out the [Getting Started with Dev Containers](getting_started_with_devcontainer.html) guide to learn more.

--------------------------------------------------------------------------------

## Choose Your Operating System

Follow the section for the operating system you use:

* [macOS](#install-ruby-on-macos)
* [Ubuntu](#install-ruby-on-ubuntu)
* [Windows](#install-ruby-on-windows)

TIP: Any commands prefaced with a dollar sign `$` should be run in the terminal.

### Install Ruby on macOS

You'll need macOS Catalina 10.15 or newer to follow these instructions.

For macOS, you'll need Xcode Command Line Tools and Homebrew to install dependencies needed to compile Ruby.

Open Terminal and run the following commands:

```bash
# Install Xcode Command Line Tools
$ xcode-select --install

# Install Homebrew and dependencies
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
$ source ~/.zshrc
$ brew install openssl@3 libyaml gmp rust

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.zshrc
$ source ~/.zshrc

# Install Ruby globally with Mise
$ mise use -g ruby@3
```

### Install Ruby on Ubuntu

You'll need Ubuntu Jammy 22.04 or newer to follow these instructions.

Open Terminal and run the following commands:

```bash
# Install dependencies with apt
$ sudo apt update
$ sudo apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc
$ source ~/.bashrc

# Install Ruby globally with Mise
$ mise use -g ruby@3
```

### Install Ruby on Windows

The Windows Subsystem for Linux (WSL) will provide the best experience for Ruby on Rails development on Windows. It runs Ubuntu inside of Windows which allows you to work in an environment that is close to what your servers will run in production.

You will need Windows 11 or Windows 10 version 2004 and higher (Build 19041 and higher).

Open PowerShell or Windows Command Prompt and run:

```bash
$ wsl --install --distribution Ubuntu-24.04
```

You may need to reboot during the installation process.

Once installed, you can open Ubuntu from the Start menu. Enter a username and password for your Ubuntu user when prompted.

Then run the following commands:

```bash
# Install dependencies with apt
$ sudo apt update
$ sudo apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
$ source ~/.bashrc

# Install Ruby globally with Mise
$ mise use -g ruby@3
```

Verifying Your Ruby Install
---------------------------

Once Ruby is installed, you can verify it works by running:

```bash
$ ruby --version
ruby 3.3.6
```

Installing Rails
----------------

A "gem" in Ruby is a self-contained package of a library or Ruby program. We can use Ruby's `gem` command to install the latest version of Rails and its dependencies from [RubyGems.org](https://rubygems.org).

Run the following command to install the latest Rails and make it available in your terminal:

```bash
$ gem install rails
```

To verify that Rails is installed correctly, run the following and you should see a version number printed out:

```bash
$ rails --version
Rails 8.0.0
```

NOTE: If the `rails` command is not found, try restarting your terminal.

You're ready to [Get Started with Rails](getting_started.html)!

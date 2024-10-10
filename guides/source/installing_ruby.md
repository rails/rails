**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Installing Ruby Guide
=====================

This guide will walk you through installing the Ruby programming language on your operating system.

While your OS might come with Ruby pre-installed, it's often outdated and can't be upgraded. Using a version manager like [Mise](https://mise.jdx.dev/getting-started.html) allows you to install the latest Ruby version, use a different Ruby version for each app, and easily upgrade to new versions when they're released.

--------------------------------------------------------------------------------

## Choose your operating system

Follow the section for the operating system you use:

* [macOS](#installing-ruby-on-macos)
* [Ubuntu](#installing-ruby-on-ubuntu)
* [Windows](#installing-ruby-on-windows)

NOTE: Any commands prefaced with a dollar sign `$` should be run in the command line.

### Installing Ruby on macOS

For macOS, you'll need XCode Command Line Tools and Homebrew to install dependencies needed to compile Ruby.

Open Terminal and run the following commands:

```shell
# Install Xcode Command Line Tools
$ xcode-select --install

# Install Homebrew and dependencies
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ export PATH="/opt/homebrew/bin:$PATH" >> ~/.zshrc
$ source ~/.zshrc
$ brew install openssl@3 libyaml gmp rust

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
$ source ~/.zshrc

# Install Ruby globally with Mise
$ mise use -g ruby@3.3.5
```

### Installing Ruby on Ubuntu

For Ubuntu, open Terminal and run the following commands:

```bash
# Install dependencies with apt
$ sudo apt update
$ sudo apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
$ source ~/.bashrc

# Install Ruby globally with Mise
$ mise use -g ruby@3.3.5
```

### Installing Ruby on Windows

The Windows Subsystem for Linux will provide the best experience for Ruby development on Windows. It runs Ubuntu inside of Windows which allows you to work in an environment that is close to what your servers will run in production.

You will need Windows 11 or Windows 10 version 2004 and higher (Build 19041 and higher).

Open PowerShell or Windows Command Prompt and run:

```bash
$ wsl --install --distribution Ubuntu
```

You may need to reboot during the installation process.

Once installed, you can open Ubuntu from the Start menu. Enter a username and password for your Ubuntu user when prompted.

```bash
# Install dependencies with apt
$ sudo apt update
$ sudo apt install build-essential rustc libssl-dev libyaml-dev zlib1g-dev libgmp-dev

# Install Mise version manager
$ curl https://mise.run | sh
$ echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
$ source ~/.bashrc

# Install Ruby globally with Mise
$ mise use -g ruby@3.3.5
```

Verifying your Ruby install
---------------------------

Once Ruby is installed, you can verify it works by running:

```bash
$ ruby --version
ruby 3.3.5
```

You're ready to [Get Started with Rails](getting_started.html)!
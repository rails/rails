# frozen_string_literal: true

require "pathname"

module Rails
  module Generators
    module JsPackageManager # :nodoc:
      MANAGERS = {
        bun: {
          name: "bun",
          add: "bun add %s",
          install: "bun install --frozen-lockfile",
          lockfile: "bun.lockb",
          audit: nil
        },
        pnpm: {
          name: "pnpm",
          add: "pnpm add %s",
          install: "pnpm install --frozen-lockfile",
          lockfile: "pnpm-lock.yaml",
          audit: "pnpm audit"
        },
        npm: {
          name: "npm",
          add: "npm install %s",
          install: "npm ci",
          lockfile: "package-lock.json",
          audit: "npm audit"
        },
        yarn: {
          name: "yarn",
          add: "yarn add %s",
          install: "yarn install --immutable",
          lockfile: "yarn.lock",
          audit: "yarn audit"
        }
      }.freeze

      def self.detect(root)
        if root.join("bun.lockb").exist? || root.join("bun.config.js").exist?
          :bun
        elsif root.join("pnpm-lock.yaml").exist?
          :pnpm
        elsif root.join("package-lock.json").exist?
          :npm
        else
          :yarn
        end
      end

      def package_manager
        @package_manager ||= JsPackageManager.detect(project_root)
      end

      def using_js_runtime?
        @using_js_runtime ||= package_json_path.exist?
      end

      def package_add_command(package)
        MANAGERS.dig(package_manager, :add) % package
      end

      def package_install_command
        MANAGERS.dig(package_manager, :install)
      end

      def package_lockfile
        MANAGERS.dig(package_manager, :lockfile)
      end

      private
        def project_root
          Pathname(respond_to?(:destination_root) ? destination_root : Dir.pwd)
        end

        def package_json_path
          project_root.join("package.json")
        end
    end
    # Alias for backwards compatibility if needed, though this is internal nodoc
    PackageManager = JsPackageManager
  end
end

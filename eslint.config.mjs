import importPlugin from "eslint-plugin-import";
import globals from "globals";
import pluginJs from "@eslint/js";

export default [
  pluginJs.configs.recommended,
  importPlugin.flatConfigs.recommended,
  {
    languageOptions: {
      globals: {
        ...globals.browser,
      },

      ecmaVersion: 6,
      sourceType: "module",
    },
  },

  {
    rules: {
      semi: ["error", "never"],
      quotes: ["error", "double"],
      "no-unused-vars": [
        "error",
        {
          vars: "all",
          args: "none",
        },
      ],
      "import/order": [
        "error",
        {
          alphabetize: {
            order: "asc",
            caseInsensitive: true,
          },
          groups: [["builtin", "external", "internal"]],
        },
      ],
    },
  },
  {
    files: ["actioncable/**"],
    rules: {
      "no-console": "off",
    },
  },
  {
    files: [
      "activestorage/app/javascript/activestorage/direct_upload.js",
      "activestorage/app/javascript/activestorage/index.js",
    ],
    rules: {
      "import/order": [
        "error",
        {
          groups: [["builtin", "external", "internal"]],
        },
      ],
    },
  },
];

module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true,
  },
  extends: [
    'standard',
    'plugin:@typescript-eslint/recommended',
    'plugin:lodash/recommended',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    requireConfigFile: false,
  },
  plugins: ['lodash', '@typescript-eslint'],
  rules: {
    'space-before-function-paren': [
      'error',
      {
        anonymous: 'always',
        named: 'never',
        asyncArrow: 'always',
      },
    ],

    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',

    'comma-dangle': ['error', 'always-multiline'],
    'object-curly-spacing': ['error', 'always'],

    'lodash/prefer-lodash-method': 'off',
    // ignore lodash variable
    'no-unused-vars': ['error', { varsIgnorePattern: '^_*' }],
  },
}

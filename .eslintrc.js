module.exports = {
  root: true,
  env: {
    node: true,
    browser: true,
  },
  plugins: ['lodash'],
  extends: ['standard', 'plugin:lodash/recommended'],
  rules: {
    'space-before-function-paren': ['error', 'never'],

    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',

    'comma-dangle': ['error', 'always-multiline'],
    'object-curly-spacing': ['error', 'always'],

    'lodash/prefer-lodash-method': 'off',
    // ignore lodash variable
    'no-unused-vars': ['error', { varsIgnorePattern: '^_*' }],
  },
  parserOptions: {
    parser: 'babel-eslint',
  },
}

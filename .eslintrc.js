module.exports = {
  root: true,
  env: {
    node: true,
    browser: true,
  },
  plugins: ['lodash'],
  extends: ['standard', 'plugin:lodash/recommended'],
  rules: {
    'no-console': process.env.NODE_ENV === 'production' ? 'error' : 'off',
    'no-debugger': process.env.NODE_ENV === 'production' ? 'error' : 'off',

    'comma-dangle': ['error', 'always-multiline'],
    'object-curly-spacing': ['error', 'always'],

    // temporary fix for the pipeline operator
    'operator-linebreak': 'off',
    'lodash/prefer-lodash-method': 'off',

    // ignore lodash variable
    'no-unused-vars': ['error', { varsIgnorePattern: '^_*' }],
  },
  parserOptions: {
    parser: 'babel-eslint',
  },
}

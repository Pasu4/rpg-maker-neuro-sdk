// @ts-check
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';
// import globals from 'globals';
import js from '@eslint/js';
import stylistic from '@stylistic/eslint-plugin';

export default defineConfig([
    { files: ['**/*.{js,mjs,cjs,ts,mts,cts}'] },
    js.configs.recommended,
    ...tseslint.configs.recommended,
    ...tseslint.configs.stylistic,
    {
        plugins: {
            '@stylistic': stylistic,
        },
        rules: {
            'curly': 'off',
            'no-useless-assignment': 'warn',
            '@typescript-eslint/no-unused-vars': [
                'warn',
                { 'argsIgnorePattern': '^_' },
            ],
            '@stylistic/semi': ['error', 'always'],
            'prefer-const': 'warn',
            '@stylistic/comma-dangle': ['warn', 'always-multiline'],
            '@stylistic/indent': ['warn', 4, {
                'flatTernaryExpressions': true,
                'SwitchCase': 1,
            }],
            '@stylistic/eol-last': ['warn', 'always'],
            '@stylistic/no-extra-parens': ['warn', 'all'],
            '@stylistic/no-trailing-spaces': ['warn', { 'ignoreComments': true }],
            '@stylistic/quotes': ['error', 'single', { 'avoidEscape': true }],
            '@typescript-eslint/no-empty-function': 'off',
        },
    },
]);

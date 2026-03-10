// @ts-check
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { FlatCompat } from '@eslint/eslintrc';
import pluginVue from 'eslint-plugin-vue';
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import vueParser from 'vue-eslint-parser';
import globals from 'globals';
import pluginImportX from 'eslint-plugin-import-x';

const __dirname = dirname(fileURLToPath(import.meta.url));
const compat = new FlatCompat({ baseDirectory: __dirname }); // Airbnb & Prettier 전용

// Nuxt 자동 import globals
const nuxtGlobals = {
  // Nuxt composables
  defineNuxtConfig: 'readonly',
  defineNuxtPlugin: 'readonly',
  defineNuxtRouteMiddleware: 'readonly',
  definePageMeta: 'readonly',
  useNuxtApp: 'readonly',
  useRuntimeConfig: 'readonly',
  useRoute: 'readonly',
  useRouter: 'readonly',
  navigateTo: 'readonly',
  abortNavigation: 'readonly',
  useFetch: 'readonly',
  useAsyncData: 'readonly',
  useState: 'readonly',
  useCookie: 'readonly',
  useHead: 'readonly',
  useSeoMeta: 'readonly',
  useError: 'readonly',
  showError: 'readonly',
  clearError: 'readonly',
  // Vue composables (auto-imported by Nuxt)
  ref: 'readonly',
  reactive: 'readonly',
  computed: 'readonly',
  watch: 'readonly',
  watchEffect: 'readonly',
  onMounted: 'readonly',
  onBeforeMount: 'readonly',
  onUnmounted: 'readonly',
  onBeforeUnmount: 'readonly',
  onUpdated: 'readonly',
  onBeforeUpdate: 'readonly',
  nextTick: 'readonly',
  provide: 'readonly',
  inject: 'readonly',
  toRef: 'readonly',
  toRefs: 'readonly',
  unref: 'readonly',
  isRef: 'readonly',
  h: 'readonly',
  defineComponent: 'readonly',
  // VueUse composables
  useNow: 'readonly',
  useLocalStorage: 'readonly',
  useSessionStorage: 'readonly',
  useToggle: 'readonly',
  useMouse: 'readonly',
  useEventListener: 'readonly',
  // vee-validate
  useForm: 'readonly',
  useField: 'readonly',
  useFieldError: 'readonly',
  useFormErrors: 'readonly',
  useFormValues: 'readonly',
  // Nuxt utils
  $fetch: 'readonly',
  // Web APIs
  HeadersInit: 'readonly',
  // Pinia stores (auto-imported)
  useAuthStore: 'readonly',
  useCounterStore: 'readonly',
};

export default [
  // 무시할 파일/디렉토리
  {
    ignores: [
      '.nuxt/**',
      '.output/**',
      'dist/**',
      'node_modules/**',
      '.claude/**',
      '**/*.config.mjs',
    ],
  },

  // Airbnb 베이스 설정 (legacy config를 flat config로 변환)
  ...compat.extends('airbnb-base'),

  // Airbnb 스타일 규칙 오버라이드
  {
    rules: {
      // ========== 변수 선언 ==========
      'no-var': 'error', // var 대신 let/const 사용
      'prefer-const': 'error', // 재할당 없으면 const 사용
      'no-undef': 'error', // 선언되지 않은 변수 사용 금지
      'no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      'no-use-before-define': ['error', { functions: false, classes: true, variables: true }],

      // ========== 함수 ==========
      'prefer-arrow-callback': 'error', // 콜백은 화살표 함수 사용
      'arrow-body-style': ['error', 'as-needed'], // 불필요한 중괄호 제거
      'no-confusing-arrow': ['error', { allowParens: true }],
      'func-style': 'off', // 함수 선언 스타일 자유롭게 (유틸리티 함수 등)
      'prefer-rest-params': 'error', // arguments 대신 ...rest 사용
      'no-new-func': 'error', // new Function 금지

      // ========== 객체/배열 ==========
      'object-shorthand': ['error', 'always'], // 객체 축약 표현 사용
      'quote-props': ['error', 'as-needed'], // 필요한 경우만 속성명 따옴표
      'prefer-destructuring': [
        'error',
        {
          VariableDeclarator: { array: false, object: true },
          AssignmentExpression: { array: false, object: false },
        },
      ],
      'prefer-object-spread': 'error', // Object.assign 대신 spread 연산자
      'prefer-spread': 'error', // apply 대신 spread 연산자
      'no-new-object': 'error', // new Object() 금지
      'no-array-constructor': 'error', // new Array() 금지

      // ========== 문자열 ==========
      'prefer-template': 'error', // 문자열 연결 시 템플릿 리터럴 사용
      'template-curly-spacing': 'error', // 템플릿 리터럴 중괄호 공백 제거
      'no-useless-concat': 'error', // 불필요한 문자열 연결 금지
      quotes: ['error', 'single', { avoidEscape: true, allowTemplateLiterals: true }],

      // ========== 비교 연산 ==========
      eqeqeq: ['error', 'always', { null: 'ignore' }], // === 사용 (null은 예외)
      'no-case-declarations': 'error', // case문에서 변수 선언 시 중괄호 필요
      'no-nested-ternary': 'error', // 중첩된 삼항 연산자 금지
      'no-unneeded-ternary': 'error', // 불필요한 삼항 연산자 금지
      'no-mixed-operators': [
        'error',
        {
          groups: [
            ['%', '**'],
            ['%', '+'],
            ['%', '-'],
            ['%', '*'],
            ['%', '/'],
            ['/', '*'],
            ['&', '|', '<<', '>>', '>>>'],
            ['==', '!=', '===', '!=='],
            ['&&', '||'],
          ],
          allowSamePrecedence: false,
        },
      ],

      // ========== 제어 흐름 ==========
      'no-else-return': ['error', { allowElseIf: false }], // else return 금지
      'no-lonely-if': 'error', // else 블록 내 단독 if 금지
      'default-case': 'error', // switch문에 default 필요
      'default-case-last': 'error', // default는 마지막에
      'no-fallthrough': 'error', // case fall-through 금지
      'no-empty': ['error', { allowEmptyCatch: true }], // 빈 블록 금지

      // ========== 모듈 ==========
      'no-duplicate-imports': 'error', // 중복 import 금지

      // Airbnb base의 import/ 규칙 비활성화 (import-x로 대체)
      'import/no-unresolved': 'off',
      'import/extensions': 'off',
      'import/prefer-default-export': 'off',
      'import/order': 'off',
      'import/no-duplicates': 'off',

      // import-x 규칙 사용
      'import-x/first': 'error', // import는 파일 최상단
      'import-x/no-mutable-exports': 'error', // let export 금지
      'import-x/newline-after-import': 'error', // import 후 빈 줄
      'import-x/no-webpack-loader-syntax': 'error', // webpack loader 구문 금지
      'import-x/order': [
        'error',
        {
          groups: ['builtin', 'external', 'internal', 'parent', 'sibling', 'index'],
          'newlines-between': 'always',
          alphabetize: { order: 'asc', caseInsensitive: true },
        },
      ], // import 순서 정렬
      'import-x/no-duplicates': 'error', // 같은 모듈 중복 import 금지

      // ========== 베스트 프랙티스 ==========
      'no-new-wrappers': 'error', // new String/Number/Boolean 금지
      'no-iterator': 'error', // __iterator__ 사용 금지
      'no-restricted-syntax': [
        'error',
        {
          selector: 'ForInStatement',
          message:
            'for..in은 성능이 좋지 않습니다. Object.keys() 또는 Object.entries()를 사용하세요.',
        },
        {
          selector: 'LabeledStatement',
          message: 'Label은 코드를 이해하기 어렵게 만듭니다.',
        },
        {
          selector: 'WithStatement',
          message: 'with는 사용하지 마세요.',
        },
      ],
      'dot-notation': ['error', { allowKeywords: true }], // 점 표기법 사용
      'one-var': ['error', 'never'], // 변수 선언은 각각 따로
      'spaced-comment': ['error', 'always'], // 주석 앞 공백
      radix: 'error', // parseInt에 radix 명시
      'no-eval': 'error', // eval 사용 금지
      'no-implied-eval': 'error', // 암묵적 eval 금지
      'no-return-assign': ['error', 'always'], // return문에 할당 금지
      'no-useless-escape': 'error', // 불필요한 이스케이프 금지
      'no-useless-return': 'error', // 불필요한 return 금지
      'no-shadow': 'off', // TypeScript에서 처리
      'no-void': 'error', // void 연산자 금지
      'prefer-promise-reject-errors': 'error', // Promise.reject에 Error 객체 사용

      // ========== 스타일 (Prettier와 중복되지 않는 것만) ==========
      camelcase: ['error', { properties: 'never', ignoreDestructuring: false }], // camelCase 사용
      'new-cap': ['error', { newIsCap: true, capIsNew: false }], // 생성자는 대문자
      'no-multiple-empty-lines': ['error', { max: 1, maxBOF: 0, maxEOF: 0 }],
      'padding-line-between-statements': [
        'error',
        { blankLine: 'always', prev: '*', next: 'return' },
        { blankLine: 'always', prev: ['const', 'let', 'var'], next: '*' },
        { blankLine: 'any', prev: ['const', 'let', 'var'], next: ['const', 'let', 'var'] },
      ],
    },
  },

  // Vue recommended 설정
  ...pluginVue.configs['flat/recommended'],

  // import-x 기본 설정 (resolver 제외)
  {
    plugins: {
      'import-x': pluginImportX,
    },
    rules: {
      ...pluginImportX.flatConfigs.recommended.rules,
      // resolver 관련 규칙 비활성화 (Nuxt 자동 import 사용)
      'import-x/no-unresolved': 'off',
      'import-x/namespace': 'off',
      'import-x/default': 'off',
      'import-x/no-named-as-default': 'off',
      'import-x/no-named-as-default-member': 'off',
      'import-x/named': 'off', // Nuxt/VueUse 자동 import로 인한 오류 방지
    },
  },

  // Prettier 설정 (반드시 마지막에 위치하여 충돌 방지)
  ...compat.extends('prettier'), // ESLint-Prettier 충돌 규칙 비활성화
  ...compat.extends('plugin:prettier/recommended'), // Prettier를 ESLint 규칙으로 실행

  // TypeScript 파일 설정 (type-aware 린팅 없이)
  {
    files: ['**/*.ts'],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
      globals: {
        ...globals.browser,
        ...globals.node,
        ...nuxtGlobals,
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      // TypeScript 관련 규칙
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': [
        'error',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],

      'no-use-before-define': 'off',
      '@typescript-eslint/no-use-before-define': ['error'],

      // Import 확장자 처리
      'import-x/extensions': 'off', // Nuxt alias (~/, @/) 사용 허용

      // Nuxt 자동 import 허용
      'import-x/no-unresolved': 'off',
      'import-x/prefer-default-export': 'off',

      // 화살표 함수 반환값 규칙 완화 (Nuxt middleware)
      'consistent-return': 'off',

      // 파라미터 재할당 허용 (Nuxt 플러그인에서 필요)
      'no-param-reassign': ['error', { props: false }],

      // console 사용 허용 (개발/디버깅용)
      'no-console': 'off',

      // underscore dangle 허용 (Nuxt $fetch의 _data)
      'no-underscore-dangle': ['error', { allow: ['_data'] }],
    },
  },

  // Vue 파일 설정 (TypeScript 포함)
  {
    files: ['**/*.vue'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tsparser,
        extraFileExtensions: ['.vue'],
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
      globals: {
        ...globals.browser,
        ...globals.node,
        ...nuxtGlobals,
      },
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      // Vue 컴포넌트 이름 규칙 (components에만 적용)
      'vue/multi-word-component-names': 'error',

      // TypeScript 관련 규칙
      'no-unused-vars': 'off',
      // Vue SFC는 템플릿 참조를 추적하지 못하므로 경고를 끔
      '@typescript-eslint/no-unused-vars': 'off',

      // Import 확장자 처리
      'import-x/extensions': 'off', // Nuxt alias (~/, @/) 사용 허용

      // Nuxt 자동 import 허용
      'import-x/no-unresolved': 'off',
      'import-x/prefer-default-export': 'off',

      // 화살표 함수 반환값 규칙 완화
      'consistent-return': 'off',

      // Vue의 setup 스크립트에서는 컴포넌트를 명시적으로 import하지 않아도 됨
      'vue/no-undef-components': 'off',

      // Vue 규칙 완화
      // v-for에서 item.id를 key로 사용해도 ESLint가 타입 추론 실패로 경고하므로 비활성화
      'vue/valid-v-for': 'off',
      'no-promise-executor-return': 'warn', // Promise executor 반환값 경고로 변경
    },
  },

  // Nuxt pages 디렉토리 예외 처리 (파일 기반 라우팅)
  {
    files: ['app/pages/**/*.vue', 'pages/**/*.vue'],
    rules: {
      // pages 폴더는 파일명이 URL이 되므로 단일 단어 허용
      // 예: [id].vue, index.vue, login.vue
      'vue/multi-word-component-names': 'off',
    },
  },

  // UI 컴포넌트 디렉토리 예외 처리 (Shadcn-vue 등)
  {
    files: ['components/ui/**/*.vue'],
    rules: {
      // UI 컴포넌트는 단일 단어 이름 허용 (Button, Badge, Avatar 등)
      'vue/multi-word-component-names': 'off',
      // prop default value 규칙 완화 (optional props)
      'vue/require-default-prop': 'off',
    },
  },

  // Layouts 디렉토리 예외 처리
  {
    files: ['layouts/**/*.vue', 'app/layouts/**/*.vue'],
    rules: {
      // layouts는 default.vue 같은 단일 단어 이름 허용
      'vue/multi-word-component-names': 'off',
    },
  },

  // 유틸리티 파일 예외 처리
  {
    files: ['lib/**/*.ts', 'utils/**/*.ts'],
    rules: {
      // 단일 export 허용
      'import/prefer-default-export': 'off',
      'import-x/prefer-default-export': 'off',
    },
  },

  // 전역 설정
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        ...nuxtGlobals,
      },
    },
    rules: {
      // 전역적으로 import/ 규칙 비활성화 (import-x 사용)
      'import/no-unresolved': 'off',
      'import/extensions': 'off',
      'import/order': 'off',
      'import/prefer-default-export': 'off',
      'import/no-duplicates': 'off',
    },
  },
];

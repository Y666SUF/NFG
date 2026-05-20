/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_NFG_API_BASE: string;
  readonly VITE_HANGMAN_WS_PATH: string;
  readonly VITE_PLATFORM_WS_PATH: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

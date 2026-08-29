// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from "@tailwindcss/vite";

export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",

  devtools: {
    enabled: true,
  },

  modules: ["@nuxt/image", "@nuxt/ui", "motion-v/nuxt"],

  css: ["~/assets/css/main.css", "~/assets/css/sm.css"],

  vite: {
    plugins: [tailwindcss()],
  },

  ssr: false,

  nitro: {
    preset: "github-pages",
  },
});

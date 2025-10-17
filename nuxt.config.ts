// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  ssr: false,
  app: {
    baseURL: '/viz/',
    head: {
      title: 'AKTEMPVIZ | Alaska Stream Temperature Data Visualization Tool',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: 'AKTEMPVIZ is a data visualization tool for exploring spatial and temporal water temperature dynamics in streams and rivers across Alaska.' },
        { name: 'author', content: 'Walker Environmental Research' },
        { name: 'keywords', content: 'AKTEMPVIZ, AKTEMP, hydrology, temperature, streams, rivers, lakes, Alaska' },
        { name: 'robots', content: 'index, follow' },
        { property: 'og:title', content: 'AKTEMPVIZ | Alaska Stream Temperature Data Viz Tool' },
        { property: 'og:description', content: 'Interactive visualizations of water temperature data across Alaska.' },
        { property: 'og:type', content: 'website' },
      ],
      link: [
        { rel: 'canonical', href: 'https://aktemp.uaa.alaska.edu/viz/' },
        { rel: 'icon', type: 'image/x-icon', href: '/viz/favicon.ico' }
      ]
    }
  },
  modules: [
    '@nuxt/eslint',
    'vuetify-nuxt-module',
    '@nuxtjs/leaflet',
    '@nuxtjs/google-fonts'
  ],
  vuetify: {
    moduleOptions: {
      /* module specific options */
    },
    vuetifyOptions: {
      /* vuetify options */
    }
  },
  googleFonts: {
    families: {
      Roboto: true,
    }
  }
})
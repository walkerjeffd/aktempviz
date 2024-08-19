/**
 * plugins/index.js
 *
 * Automatically included in `./src/main.js`
 */

// Plugins
import './leaflet'

import vuetify from './vuetify'
import highcharts from './highcharts'
import pinia from '@/stores'
import router from '@/router'

export function registerPlugins (app) {
  app
    .use(vuetify)
    .use(router)
    .use(pinia)
    .use(highcharts)
}

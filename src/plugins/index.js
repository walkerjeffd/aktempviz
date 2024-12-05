/**
 * plugins/index.js
 *
 * Automatically included in `./src/main.js`
 */

// Plugins
import './leaflet'
import './driver'

import vuetify from './vuetify'
import highcharts from './highcharts'
import router from '@/router'

export function registerPlugins (app) {
  app
    .use(vuetify)
    .use(router)
    .use(highcharts)
}

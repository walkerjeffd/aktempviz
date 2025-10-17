import * as Highcharts from 'highcharts'
import 'highcharts/highcharts-more'
import 'highcharts/modules/stock'
import 'highcharts/modules/exporting'
import 'highcharts/modules/no-data-to-display'

Highcharts.setOptions({
  lang: {
    thousandsSep: ','
  },
  colors: ['#004895']
})

export default defineNuxtPlugin(() => {})
<template>
  <v-container>
    <v-row>
      <v-col cols="4">
        <v-card>
          <v-card-title>Stations Map</v-card-title>
          <v-card-text>
            <div style="width:100%;height:500px">
              <LMap ref="map" :zoom="4" :center="[63,-150]" @ready="mapReady">
                <LTileLayer
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                  layer-type="base"
                  name="OpenStreetMap"
                ></LTileLayer>
                <LCircleMarker
                  v-for="station in selectedStations"
                  :key="station.properties.station_id"
                  :lat-lng="[station.geometry.coordinates[1], station.geometry.coordinates[0]]"
                  :radius="10"
                  :color="station.color"
                  @click="selectStation(station)"
                ></LCircleMarker>
              </LMap>
            </div>
            <div>
              <pre>TODO: legend (blue=AKTEMP, green=USGS, orange=FWS)
      alternative basemaps (USGS, satellite)</pre>
            </div>
          </v-card-text>

          <v-divider></v-divider>

          <v-card-title>Selected Stations</v-card-title>
          <v-card-text v-if="selectedStations.length > 0">
            <ul class="px-4">
              <li v-for="station in selectedStations">
                {{ station.properties.station_id }} (n = {{ station.data.length.toLocaleString() }})
              </li>
            </ul>

            <div class="py-4">
              <v-btn :disabled="selectedStations.length === 0" @click="clear">Clear</v-btn>
            </div>

            <pre class="pt-4">TODO: dropdown for searching/selecting stations
      station filters (data source, start/end date, min. # days)</pre>
          </v-card-text>
          <v-card-text v-else>
            <div>No stations selected. Click a station on the map to select it.</div>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="8">
        <v-row>
          <v-col cols="12">
            <v-card>
              <!-- <v-card-title>Timeseries Chart</v-card-title> -->
              <highcharts :constructor-type="'stockChart'" :options="timeseriesChartSettings" ref="timeseriesChart"></highcharts>
              <pre class="px-4">TODO: filter data by selected time window</pre>
            </v-card>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="6">
            <v-card>
              <!-- <v-card-title>Seasonal Chart</v-card-title> -->
              <v-card-text>
                <highcharts :options="seasonalChartSettings" ref="seasonalChart"></highcharts>
              </v-card-text>
              <pre class="px-4">TODO: filter data by selected seasonal range</pre>
            </v-card>
          </v-col>
          <v-col cols="6">
            <v-card>
              <!-- <v-card-title>Air vs Water Temp Scatterplot</v-card-title> -->
              <v-card-text>
                <highcharts :options="scatterChartSettings" ref="scatterChart"></highcharts>
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { LMap, LTileLayer, LCircleMarker } from '@vue-leaflet/vue-leaflet'
import { ref, computed } from 'vue'
import { groups } from 'd3-array'
import { schemeObservable10 } from 'd3-scale-chromatic'
import { DateTime } from 'luxon'

const map = ref(null)
const loading = ref(false)
const selectedStations = ref([])
const timeseriesChart = ref(null)
const seasonalChart = ref(null)
const scatterChart = ref(null)

async function createLayer (layer) {
  const url = layer.options.url
  const response = await fetch(url)
  const geojson = await response.json()
  return new L.GeoJSON(geojson, layer.options)
}

const datasetColors = {
  'AKTEMP': '#4075b0',
  'NPS': '#ee8830',
  'USGS': '#509e3d'
}

function stationPopupTable (feature) {
  return `
    <div class="text-body-1 font-weight-bold">${feature.properties.station_id}</div>
    <div class="text-body-2">${feature.properties.start} to ${feature.properties.end}</div>
  `
}

function restyleStationsLayer (layer) {
  layer.setStyle({
    radius: 5,
    opacity: selectedStations.value.length > 0 ? 0.2 : 0.5
  })
}

function clear () {
  selectedStations.value.length = 0
  colors = schemeObservable10.slice()
  updateCharts()
}

const seasonalChartSettings = {
  chart: {
    type: 'line',
    zoomType: 'xy',
  },
  plotOptions: {
    series: {
      // opacity: 0.5,
      marker: {
        // radius: 2
      },
      states: {
        hover: {
          // enabled: false,
          // opacity: 1
        },
        inactive: {
          // enabled: false
          // opacity: 0.5
        }
      }
    },
  },
  title: {
    text: 'Seasonal Water Temperature'
  },
  xAxis: {
    min: 0,
    max: 365,
    title: {
      text: 'Day of Year'
    }
  },
  yAxis: {
    min: 0,
    title: {
      text: 'Temperature (degC)'
    }
  },
  tooltip: {
    shared: false,
    useHTML: true,
    formatter: function () {
      const stationId = this.point.station_id
      const year = this.point.year
      const date = DateTime.fromObject({ year, day: 1, month: 1 }, { zone: 'UTC' }).plus({ days: this.x }).toISODate()
      return `<table>
        <tbody>
          <tr>
            <td class="pr-2 text-right">Station</td>
            <td><b>${stationId}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Date</td>
            <td><b>${date}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Water Temp</td>
            <td><b>${this.y.toFixed(1)} °C</b></td>
          </tr>
        </tbody>
      </table>`
    }
  },
}

const scatterChartSettings = {
  chart: {
    type: 'scatter',
    zoomType: 'xy',
  },
  plotOptions: {
    series: {
      opacity: 0.75,
      marker: {
        radius: 2
      }
    },
  },
  title: {
    text: 'Air vs Water Temperature'
  },
  xAxis: {
    title: {
      text: 'Air Temperature (degC)'
    }
  },
  yAxis: {
    min: 0,
    title: {
      text: 'Water Temperature (degC)'
    }
  },
  tooltip: {
    shared: false,
    useHTML: true,
    formatter: function () {
      const stationId = this.point.station_id
      const date = this.point.date
      return `<table>
        <tbody>
          <tr>
            <td class="pr-2 text-right">Station</td>
            <td><b>${stationId}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Date</td>
            <td><b>${date}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Air Temp</td>
            <td><b>${this.x.toFixed(1)} °C</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Water Temp</td>
            <td><b>${this.y.toFixed(1)} °C</b></td>
          </tr>
        </tbody>
      </table>`
    }
  }
}

const timeseriesChartSettings = {
  chart: {
    height: 500,
    marginLeft: 70,
    zoomType: 'x',
    // animation: false,
    boost: {
      enabled: false
    },
    events: {
      // selection: this.onBrush,
      // load: () => console.log('chart:load'),
      // redraw: () => console.log('chart:redraw'),
      // render: () => console.log('chart:render')
    }
  },
  title: {
    text: 'Timeseries'
  },
  plotOptions: {
    series: {
      gapSize: 1,
    },
  },
  lang: {
    noData: 'No data to display'
  },
  noData: {
    style: {
      fontWeight: 'bold',
      fontSize: '15px',
      color: '#303030'
    }
  },
  loading: {
    style: {
      position: 'absolute',
      backgroundColor: '#ffffff',
      opacity: 1,
      textAlign: 'center'
    }
  },
  legend: {
    enabled: true,
    align: 'right'
  },
  tooltip: {
    shared: false,
    useHTML: true,
    formatter: function () {
      const stationId = this.point.station_id
      const date = this.point.date
      return `<table>
        <tbody>
          <tr>
            <td class="pr-2 text-right">Station</td>
            <td><b>${stationId}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Date</td>
            <td><b>${date}</b></td>
          </tr>
          <tr>
            <td class="pr-2 text-right">Water Temp</td>
            <td><b>${this.y.toFixed(1)} °C</b></td>
          </tr>
        </tbody>
      </table>`
    }
  },
  // scrollbar: {
  //   liveRedraw: false
  // },
  navigator: {
    adaptToUpdatedData: false,
    // series: {
    //   id: 'navigator',
    //   type: 'areaspline',
    //   color: undefined,
    //   data: [],
    //   // gapSize: 0,
    //   dataGrouping: {
    //     enabled: false
    //   },
    //   // visible: true,
    //   showInNavigator: true
    // }
  },
  rangeSelector: {
    selected: 4,
    buttons: [{
      type: 'month',
      count: 1,
      text: '1m',
      title: 'View 1 month'
    }, {
      type: 'month',
      count: 3,
      text: '3m',
      title: 'View 3 months'
    }, {
      type: 'month',
      count: 6,
      text: '6m',
      title: 'View 6 months'
    }, {
      type: 'year',
      count: 1,
      text: '1y',
      title: 'View 1 year'
    }, {
      type: 'all',
      text: 'All',
      title: 'View all'
    }]
  },
  xAxis: {
    ordinal: false,
    minRange: 24 * 3600 * 1000,
    events: {
      // afterSetExtremes: this.afterSetExtremes
    }
  },
  yAxis: {
    allowDecimals: false,
    opposite: false,
    startOnTick: false,
    endOnTick: false,
    tickAmount: 8,
    title: {
      text: 'Temperature (degC)'
    },
    min: 0
  },
  credits: {
    enabled: false
  },
  series: []
}

function updateCharts () {
  updateTimeseriesChart()
  updateSeasonalChart()
  updateScatterChart()
}

function updateTimeseriesChart () {
  if (!map.value) return
  const chart = timeseriesChart.value.chart
  if (!chart) return

  const series = selectedStations.value.map(station => {
    return {
      name: station.properties.station_id,
      data: station.data.map(d => ({ x: new Date(d.date).valueOf(), y: d.temp_c, date: d.date, station_id: station.properties.station_id })),
      color: station.color,
      showInNavigator: true,
    }
  })

  chart.update({
    series: series
  }, true, true)
}

// window.DateTime = DateTime
function julianDay (dateString) {
  const d = DateTime.fromISO(dateString)
  return d.diff(d.startOf('year'), 'days').days
}

function updateSeasonalChart () {
  if (!map.value) return
  const chart = seasonalChart.value.chart
  if (!chart) return

  const stationYearData = selectedStations.value.map(station => {
    const dataByYear = groups(station.data, d => d.date.slice(0, 4))
    return dataByYear.map((d, i) => {
      const year = +d[0]
      console.log(year)
      return {
        station_id: station.properties.station_id,
        year: +d[0],
        color: station.color,
        data: d[1].map(d => ({ x: julianDay(d.date), y: d.temp_c, year, station_id: station.properties.station_id })),
        linkedTo: i > 0 ? ':previous' : undefined
      }
    })
  })
  const series = stationYearData.flat().map(d => {
    return {
      id: `${d.station_id} ${d.year}`,
      name: `${d.station_id}`,
      color: d.color,
      linkedTo: d.linkedTo,
      station_id: d.station_id,
      data: d.data
    }
  })

  chart.update({
    series: series
  }, true, true)
}

function updateScatterChart () {
  if (!map.value) return
  const chart = scatterChart.value.chart
  if (!chart) return

  const series = selectedStations.value.map(station => {
    return {
      name: station.properties.station_id,
      data: station.data.map(d => ({ x: d.airtemp_c, y: d.temp_c, date: d.date, station_id: station.properties.station_id })),
      color: station.color,
    }
  })

  chart.update({
    series: series
  }, true, true)
}

const stations = {
  data: null,
  mapLayer: null,
  options: {
    id: 'stations',
    url: 'data/stations.json',
    title: 'Stations',
    visible: true,
    interactive: true,
    top: true,
    pointToLayer: (feature, latlng) => {
      return L.circleMarker(latlng, {
        color: datasetColors[feature.properties.dataset],
        fillColor: datasetColors[feature.properties.dataset],
        radius: 5,
        // fillColor: '#019137',
        weight: 1,
        opacity: 0.5,
        fillOpacity: 0.25
      })
    },
    onEachFeature: function (feature, layer) {
      layer.bindTooltip(`${stationPopupTable(feature)}`, { sticky: true })
      layer.on({
        click: (e) => {
          const feature = e.target.feature
          selectStation(feature)
        },
        mouseover: () => {
          layer.setStyle({
            radius: 10
          })
        },
        mouseout: () => {
          restyleStationsLayer(layer)
        }
      })
    }
  }
}

let colors = schemeObservable10.slice()

async function selectStation (station) {
  station.data = await fetchData(station)
  if (selectedStations.value.some(d => d.properties.station_id === station.properties.station_id)) {
    selectedStations.value = selectedStations.value.filter(d => d.properties.station_id !== station.properties.station_id)
    colors.unshift(station.color)
  } else {
    station.color = colors.shift()
    selectedStations.value.push(station)
  }
  restyleStationsLayer(stations.mapLayer)
  updateCharts()
}

async function mapReady (map) {
  loading.value = true

  const stationsLayer = await createLayer(stations)
  stations.mapLayer = stationsLayer
  map.addLayer(stationsLayer)

  loading.value = false
}

async function fetchData (station) {
  if (station.data) return station.data
  const response = await fetch(`data/stations/${station.properties.filename}`)
  return await response.json()
}

</script>

<style>

.table-predictions-container {
  width: 300px;;
  overflow-x: auto;
}

.table-predictions {
  display: block !important;
  margin-bottom: 10px;
}

.table-predictions th {
  text-align: center !important;
}

.table-predictions td {
  text-align: center !important;
}

.table-predictions span.thermal-cold {
  padding: 2px;
  background-color: #2C7BB6 !important;
  color: white;
}

.table-predictions span.thermal-cool {
  padding: 2px;
  background-color: #ABD9E9 !important;
}

.table-predictions span.thermal-warm {
  padding: 2px;
  background-color: #FDAE61 !important;
}

/* remove the focus ring */
path.leaflet-interactive:focus {
    outline: none;
}
</style>
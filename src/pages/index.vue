<template>
  <v-container>
    <v-row>
      <v-col cols="4">
        <v-card>
          <v-card-text>
            <div style="width:100%;height:500px">
              <StationMap :selected="selectedStations" @select="selectStationOnMap" @load="setStations"></StationMap>
            </div>
          </v-card-text>

          <v-divider></v-divider>

          <v-card-text class="pt-0">
            <div class="d-flex">
              <v-text-field
                v-model="search"
                label="Search Stations"
                prepend-inner-icon="mdi-magnify"
                variant="underlined"
                hide-details
                single-line
                class="px-4"
              ></v-text-field>

              <div class="py-4">
                <v-btn
                  :disabled="selectedStations.length === 0"
                  @click="clear"
                  variant="outlined"
                >
                  Clear
                </v-btn>
              </div>
            </div>

            <div class="px-4 text-caption pt-0 mt-0">
              <span v-if="selectedStations.length > 0">
                {{ selectedStations.length }} station<span v-if="selectedStations.length > 1">s</span> selected
              </span>
              <span v-else>
                No stations selected. Click a station on the map or select from the table below.
              </span>
            </div>

            <v-data-table
              v-model="selectedStations"
              :headers="headers"
              :items="stations"
              :loading="loading"
              :search="search"
              items-per-page-text="Stations per Page"
              :items-per-page-options="[5, 10, 25, 50, 100, -1]"
              density="compact"
              item-key="id"
              items-per-page="5"
              show-select
              return-object
              width="100%"
            >
              <template v-slot:header.data-table-select></template>
              <template v-slot:item.data-table-select="{ internalItem, isSelected, toggleSelect }">
                <v-checkbox-btn
                  :model-value="isSelected(internalItem)"
                  :color="isSelected(internalItem) ? internalItem.value.color : 'grey'"
                  @update:model-value="toggleSelect2(internalItem, isSelected, toggleSelect)"
                ></v-checkbox-btn>
              </template>
            </v-data-table>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="8">
        <v-row>
          <v-col cols="12">
            <v-card>
              <TimeseriesChart :series="series" @zoom="onTimeseriesZoom" :loading="loading" />
            </v-card>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="6">
            <v-card>
              <v-card-text>
                <SeasonalChart :series="filteredSeries" :loading="loading" />
              </v-card-text>
            </v-card>
          </v-col>
          <v-col cols="6">
            <v-card>
              <v-card-text>
                <ScatterChart :series="filteredSeries" :loading="loading" />
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref, computed } from 'vue'
import { schemeSet1 } from 'd3-scale-chromatic'

import StationMap from '@/components/StationMap'
import TimeseriesChart from '@/components/TimeseriesChart'
import SeasonalChart from '@/components/SeasonalChart'
import ScatterChart from '@/components/ScatterChart'

const stations = ref([])
const selectedStations = ref([])
const timeRange = ref(null)
const loading = ref(false)
const search = ref('')

function clear () {
  selectedStations.value.length = 0
  colors = schemeSet1.slice()
}

const headers = [
  {
    title: 'Station ID',
    sortable: true,
    value: 'properties.station_id',
    nowrap: false
  },
  // {
  //   title: 'Start',
  //   sortable: true,
  //   value: 'properties.start'
  // },
  // {
  //   title: 'End',
  //   sortable: true,
  //   value: 'properties.end'
  // },
  {
    title: '# Daily Values',
    sortable: true,
    align: 'end',
    value: 'properties.n'
   }
]

let colors = schemeSet1.slice()

function setStations (x) {
  stations.value = x
}

async function toggleSelect2 (item, isSelected, toggleSelect) {
  const station = item.value
  if (isSelected(item)) {
    await unselectStation(station)
  } else {
    await selectStation(station)
  }
  toggleSelect(item)
}

async function selectStationOnMap (station) {
  if (selectedStations.value.some(d => d.id === station.id)) {
    unselectStation(station)
    selectedStations.value = selectedStations.value.filter(d => d.id !== station.id)
  } else {
    await selectStation(station)
    selectedStations.value.push(station)
  }
}

async function selectStation (station) {
  station.data = await fetchData(station)
  station.color = colors.shift()
}

async function unselectStation (station) {
  colors.unshift(station.color)
}

const series = computed(() => {
  return selectedStations.value.map(station => {
    return {
      station_id: station.properties.station_id,
      color: station.color,
      showInNavigator: true,
      data: station.data.map(d => ({
        millis: new Date(d.date).valueOf(),
        date: d.date,
        year: +d.date.slice(0, 4),
        temp_c: d.temp_c,
        airtemp_c: d.airtemp_c,
        station_id: station.properties.station_id
      })),
    }
  })
})

const filteredSeries = computed(() => {
  return series.value.map(s => {
    return {
      ...s,
      data: s.data.filter(d => {
        if (!timeRange.value) return true
        return d.millis >= (timeRange.value[0]).valueOf() && d.millis <= (timeRange.value[1]).valueOf()
      })
    }
  })
})

function onTimeseriesZoom (range) {
  timeRange.value = range
}

async function fetchData (station) {
  if (station.data) return station.data
  loading.value = true
  const response = await fetch(`data/stations/${station.properties.filename}`)
  const json = await response.json()
  loading.value = false
  return json
}

</script>

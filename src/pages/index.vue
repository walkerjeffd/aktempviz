<template>
  <v-container fluid>
    <v-row>
      <v-col cols="12" lg="5" xl="4">
        <v-card>
          <v-card-text>
            <div style="width:100%;height:500px">
              <StationMap :stations="filteredStations" :selected="selectedStations" @select="selectStation"></StationMap>
            </div>
          </v-card-text>

          <v-divider></v-divider>

          <div class="d-flex align-center py-4 pr-4">
            <div class="px-4 text-overline font-weight-bold">
              <span v-if="selectedStations.length > 0">
                {{ selectedStations.length }} station<span v-if="selectedStations.length > 1">s</span> selected
              </span>
              <span v-else class="text-primary">
                Select a station on the map or table below.
              </span>
            </div>

            <v-spacer></v-spacer>
            <div>
              <v-btn
                size="small"
                variant="outlined"
                :disabled="selectedStations.length === 0"
                @click="clearSelection"
              >
                Unselect All
              </v-btn>
            </div>
          </div>

          <div class="text-error px-4 pb-4" v-if="selectedStations.length >= maxSelected">
            <v-icon size="x-small">mdi-alert</v-icon>
            Maximum of {{ maxSelected }} stations selected. Unselect one to select another.
          </div>

          <v-divider></v-divider>

          <div class="d-flex pr-4">
            <v-text-field
              v-model="filterStationId"
              label="Search Stations"
              prepend-inner-icon="mdi-magnify"
              variant="underlined"
              hide-details
              single-line
              class="px-4"
            ></v-text-field>

            <div class="py-4">
              <v-menu v-model="showFilters" :close-on-content-click="false">
                <template v-slot:activator="{ props }">
                  <v-btn
                    :color="filtersEnabled ? 'primary' : 'default'"
                    variant="outlined"
                    size="small"
                    v-bind="props"
                  >
                    <v-icon left>mdi-filter-outline</v-icon>
                    Filters
                  </v-btn>
                </template>
                <v-sheet class="pa-4" style="width:300px">
                  <div class="pt-4">
                    <v-text-field
                      v-model="filterBefore"
                      clearable
                      label="Observations Start Before"
                      variant="outlined"
                      density="compact"
                      persistent-hint
                      hint="YYYY-MM-DD format"
                      class="mb-4"
                    ></v-text-field>
                    <v-text-field
                      v-model="filterAfter"
                      clearable
                      label="Observations End After"
                      variant="outlined"
                      density="compact"
                      persistent-hint
                      hint="YYYY-MM-DD format"
                      class="mb-4"
                    ></v-text-field>
                    <v-text-field
                      v-model="filterCount"
                      clearable
                      label="Min. Daily Observations"
                      variant="outlined"
                      density="compact"
                      type="number"
                      persistent-hint
                      hint="Integer number"
                    ></v-text-field>
                    <v-checkbox v-model="filterSelected" label="Selected Stations Only" hide-details></v-checkbox>
                  </div>

                  <div class="d-flex">
                    <v-btn variant="outlined" @click="showFilters = false" class="mt-4">
                      <v-icon left>mdi-close</v-icon> Close
                    </v-btn>
                    <v-spacer></v-spacer>
                    <v-btn variant="outlined" color="error" @click="resetFilters" class="mt-4">
                      <v-icon left>mdi-refresh</v-icon> Reset
                    </v-btn>
                  </div>
                </v-sheet>
              </v-menu>
            </div>
          </div>

          <v-data-table
            v-model="selectedStations"
            :headers="headers"
            :items="filteredStations"
            :loading="loading"
            items-per-page-text="# per Page"
            :items-per-page-options="[5, 10, 25, 50, 100, -1]"
            density="compact"
            item-key="id"
            items-per-page="5"
            show-select
            return-object
            width="100%"
          >
            <template v-slot:header.data-table-select></template>
            <template v-slot:item.start="{ item }">{{ item.start.substr(0, 4) }}</template>
            <template v-slot:item.end="{ item }">{{ item.end.substr(0, 4) }}</template>
            <template v-slot:item.n="{ item }">{{ item.n.toLocaleString() }}</template>
            <template v-slot:item.data-table-select="{ internalItem, isSelected, toggleSelect }">
              <v-checkbox-btn
                :model-value="isSelected(internalItem)"
                :color="isSelected(internalItem) ? internalItem.value.color : 'grey'"
                @update:model-value="selectStation(internalItem.value)"
              ></v-checkbox-btn>
            </template>
          </v-data-table>
        </v-card>
      </v-col>

      <v-col cols="12" lg="7" xl="8">
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
import { ref, computed, onMounted } from 'vue'
import { schemeSet1 } from 'd3-scale-chromatic'
import { DateTime } from 'luxon'

import StationMap from '@/components/StationMap'
import TimeseriesChart from '@/components/TimeseriesChart'
import SeasonalChart from '@/components/SeasonalChart'
import ScatterChart from '@/components/ScatterChart'

const stations = ref([])
const selectedStations = ref([])
const timeRange = ref(null)
const loading = ref(false)

const maxSelected = 5
const showFilters = ref(false)
const filterStationId = ref('')
const filterSelected = ref(false)
const filterAfter = ref('')
const filterBefore = ref('')
const filterCount = ref(null)

const filtersEnabled = computed(() => {
  return filterStationId.value || filterSelected.value || filterAfter.value || filterBefore.value || filterCount.value
})

function resetFilters () {
  filterSelected.value = false
  filterAfter.value = ''
  filterBefore.value = ''
  filterCount.value = null
}

function clearSelection () {
  selectedStations.value.forEach(d => {
    d.isSelected = false
  })
  selectedStations.value.length = 0
  colors = schemeSet1.slice()
}

const headers = [
  {
    title: 'Station ID',
    sortable: true,
    value: 'station_id',
    nowrap: false,
    maxWidth: '250px'
  },
  {
    title: 'Start',
    sortable: true,
    align: 'end',
    value: 'start',
    width: '20px'
  },
  {
    title: 'End',
    sortable: true,
    align: 'end',
    value: 'end',
    width: '20px'
  },
  {
    title: 'Count',
    sortable: true,
    align: 'end',
    value: 'n',
    width: '10px'
   }
]

let colors = schemeSet1.slice()

onMounted(async () => {
  stations.value = await fetchStations()
})

async function selectStation (station) {
  if (selectedStations.value.some(d => d.station_id === station.station_id)) {
    colors.unshift(station.color)
    station.isSelected = false
    selectedStations.value = selectedStations.value.filter(d => d.station_id !== station.station_id)
  } else {
    if (selectedStations.value.length >= maxSelected) return
    station.isSelected = true
    station.data = await fetchData(station)
    station.color = colors.shift()
    selectedStations.value.push(station)
  }
}

const series = computed(() => {
  return selectedStations.value.map(station => {
    return {
      station_id: station.station_id,
      color: station.color,
      showInNavigator: true,
      data: station.data.map(d => ({
        millis: new Date(d.date).valueOf(),
        date: d.date,
        year: +d.date.slice(0, 4),
        temp_c: d.temp_c,
        airtemp_c: d.airtemp_c,
        station_id: station.station_id
      })),
    }
  })
})

const filteredStations = computed(() => {
  return stations.value.filter(station => {
    return (!filterStationId.value || station.station_id.toLowerCase().includes(filterStationId.value.toLowerCase())) &&
      (!filterSelected.value || station.isSelected) &&
      (!filterBefore.value || station.start <= filterBefore.value) &&
      (!filterAfter.value || station.end >= filterAfter.value) &&
      (!filterCount.value || station.n >= parseInt(filterCount.value, 10))
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

async function fetchStations () {
  loading.value = true
  const response = await fetch(`data/stations.json`)
  const json = await response.json()
  loading.value = false
  return json
}

async function fetchData (station) {
  if (station.data) return station.data
  loading.value = true
  const response = await fetch(`data/stations/${station.filename}`)
  const json = await response.json()
  loading.value = false
  return json
}

</script>

<template>
  <v-container fluid>
    <v-row>
      <v-col cols="12" lg="5" xl="4">
        <v-card>
          <v-card-text>
            <div style="width:100%;height:500px">
              <StationMap
                :stations="filteredStations"
                :selected="selectedStations"
                :selected-basin="selectedBasin"
                :basin-layer="selectedBasinLayer"
                @select="selectStation"
                @select-basin="selectBasin"
              >
              </StationMap>
            </div>
          </v-card-text>

          <v-divider></v-divider>

          <div class="pa-4">
            <div
              v-if="selectedStations.length === 0"
              class="text-overline text-primary font-weight-bold"
            >
              Select a station on the map or table below.
            </div>

            <div v-else>
              <div class="d-flex align-center mb-2">
                <div class="text-overline text-primary font-weight-bold">
                  Selected Stations
                </div>
                <v-spacer></v-spacer>
                <v-btn size="small" variant="outlined" v-if="selectedStations.length > 0" @click="clearSelection">
                  Unselect All
                </v-btn>
              </div>
              <div class="d-flex flex-wrap">
                <v-chip
                  v-for="station in selectedStations"
                  :key="station.station_id"
                  class="mr-1 mb-1"
                  :color="station.color"
                  closable
                  @click:close="selectStation(station)"
                >
                  {{ station.station_id }}
                </v-chip>
              </div>
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
                    :color="filtersEnabled ? 'warning' : 'default'"
                    variant="outlined"
                    size="small"
                    v-bind="props"
                  >
                    <v-icon left>mdi-filter-outline</v-icon>
                    Filters
                  </v-btn>
                </template>
                <v-sheet style="width:350px">
                  <div class="pa-4 text-h6">Station Filters</div>

                  <v-divider></v-divider>

                  <div class="px-4 pt-4">
                    <v-select
                      v-model="selectedBasinLayer"
                      :items="basinLayerOptions"
                      item-title="label"
                      item-value="value"
                      label="Basins Layer"
                      density="compact"
                      variant="outlined"
                      clearable
                      hint="Only stations within a selected basin. Select a basin layer, then click a basin on the map."
                      persistent-hint
                      class="mb-4"
                    ></v-select>
                    <v-text-field
                      v-model="filterBefore"
                      clearable
                      label="Observations Start Before"
                      placeholder="YYYY-MM-DD"
                      variant="outlined"
                      density="compact"
                      persistent-hint
                      hint="Only stations with data stating before this date."
                      class="mb-4"
                    ></v-text-field>
                    <v-text-field
                      v-model="filterAfter"
                      clearable
                      label="Observations End After"
                      placeholder="YYYY-MM-DD"
                      variant="outlined"
                      density="compact"
                      persistent-hint
                      hint="Only stations with data ending after this date."
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
                      hint="Only stations with at least this many daily values."
                      class="mb-4"
                    ></v-text-field>
                  </div>

                  <v-divider></v-divider>

                  <div class="d-flex pa-4">
                    <v-btn variant="outlined" aria-label="Close station filters" @click="showFilters = false">
                      <v-icon left>mdi-close</v-icon> Close
                    </v-btn>
                    <v-spacer></v-spacer>
                    <v-btn variant="outlined" color="error" aria-label="Reset station filters" @click="resetFilters">
                      <v-icon left>mdi-refresh</v-icon> Reset
                    </v-btn>
                  </div>
                </v-sheet>
              </v-menu>
            </div>
          </div>

          <div class="d-flex flex-wrap pa-2">
            <v-chip
              v-for="filter in activeFilters"
              :key="filter.type"
              class="ma-1"
              closable
              @click:close="removeFilter(filter.type)"
            >
              {{ filter.label }}&nbsp;<b>{{ filter.value }}</b>
            </v-chip>
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
            <template v-slot:header.data-table-select>
              <v-checkbox-btn
                v-model="filterSelected"
              ></v-checkbox-btn>
            </template>
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
          <v-col cols="12" md="6">
            <v-card>
              <v-card-text>
                <SeasonalChart :series="filteredSeries" :loading="loading" />
              </v-card-text>
            </v-card>
          </v-col>
          <v-col cols="12" md="6">
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
import { ref, computed, onMounted, watch } from 'vue'
import { schemeSet1 } from 'd3-scale-chromatic'
import booleanPointInPolygon from '@turf/boolean-point-in-polygon'

import StationMap from '@/components/StationMap'
import TimeseriesChart from '@/components/TimeseriesChart'
import SeasonalChart from '@/components/SeasonalChart'
import ScatterChart from '@/components/ScatterChart'

const stations = ref([])
const selectedStations = ref([])
const selectedBasin = ref(null)
const timeRange = ref(null)
const loading = ref(false)

const maxSelected = 5
const showFilters = ref(false)
const filterStationId = ref('')
const filterSelected = ref(false)
const filterAfter = ref('')
const filterBefore = ref('')
const filterCount = ref(null)

const basinLayerOptions = ref([
  {
    value: 'huc4',
    label: 'Large Basins (HUC4)'
  },
  {
    value: 'huc6',
    label: 'Medium Basins (HUC6)'
  },
  {
    value: 'huc8',
    label: 'Small Basins (HUC8)'
  }
])
const selectedBasinLayer = ref(null)

const filtersEnabled = computed(() => {
  return (selectedBasinLayer.value && selectedBasin.value) || filterAfter.value || filterBefore.value || filterCount.value
})

const activeFilters = computed(() => {
  const filters = []

  if (selectedBasinLayer.value && selectedBasin.value) {
    filters.push({
      type: 'basin',
      label: 'Basin: ',
      value: `${selectedBasin.value.properties.name} (${selectedBasin.value.id})`
    })
  }

  if (filterAfter.value) {
    filters.push({
      type: 'after',
      label: 'End >= ',
      value: filterAfter.value
    })
  }

  if (filterBefore.value) {
    filters.push({
      type: 'before',
      label: 'Start <=',
      value: filterBefore.value
    })
  }

  if (filterCount.value) {
    filters.push({
      type: 'count',
      label: '# Days >= ',
      value: filterCount.value
    })
  }

  return filters
})

function removeFilter(filterType) {
  switch (filterType) {
    case 'basin':
      // selectedBasinLayer.value = null
      selectedBasin.value = null
      break
    case 'stationId':
      filterStationId.value = ''
      break
    case 'selected':
      filterSelected.value = false
      break
    case 'after':
      filterAfter.value = ''
      break
    case 'before':
      filterBefore.value = ''
      break
    case 'count':
      filterCount.value = null
      break
  }
}

function resetFilters () {
  filterSelected.value = false
  filterAfter.value = ''
  filterBefore.value = ''
  filterCount.value = null
  selectedBasinLayer.value = null
  selectedBasin.value = null
}

function clearSelection () {
  selectedStations.value.forEach(d => {
    d.isSelected = false
  })
  selectedStations.value.length = 0
  colors = defaultColors.slice()
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
    title: '# Days',
    sortable: true,
    align: 'end',
    value: 'n',
    width: '100px'
   }
]

// const defaultColors = [
//   '#2E5DAB',
// 	'#D84727',
// 	'#EFC12F',
// 	'#78909C',
// 	'#7B519D'
// ]
const defaultColors = [
  '#1b9e77',
  '#d95f02',
  '#7570b3',
  '#e7298a',
  '#66a61e'
]
let colors = defaultColors.slice()

onMounted(async () => {
  stations.value = await fetchStations()
})

async function selectStation (station) {
  console.log('selectStation', station)
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

async function selectBasin (basin) {
  if (!basin || basin.id === selectedBasin.value?.id) {
    selectedBasin.value = null
    return
  }
  selectedBasin.value = basin
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
    return (!filterSelected.value || station.isSelected) &&
      (!filterStationId.value || station.station_id.toLowerCase().includes(filterStationId.value.toLowerCase())) &&
      (!filterBefore.value || station.start <= filterBefore.value) &&
      (!filterAfter.value || station.end >= filterAfter.value) &&
      (!filterCount.value || station.n >= parseInt(filterCount.value, 10)) &&
      (!selectedBasin.value || booleanPointInPolygon([station.longitude, station.latitude], selectedBasin.value))
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

watch(
  [selectedStations, filterSelected],
  ([newSelectedStations, newFilterSelected]) => {
    if (newFilterSelected && newSelectedStations.length === 0) {
      filterSelected.value = false;
    }
  }
)

</script>

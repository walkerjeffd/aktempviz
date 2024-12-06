<template>
  <v-app-bar color="primary" density="compact">
    <v-app-bar-title>AKTEMP<span class="text-caption">VIZ</span> | Stream Temperature Data Visualization Tool</v-app-bar-title>

    <v-btn
      color="white"
      variant="text"
      @click="showWelcome = true"
    >
      <v-icon start>mdi-information-outline</v-icon>
      Welcome
    </v-btn>
    <v-btn
      color="white"
      variant="text"
      @click="startTour"
    >
      <v-icon start>mdi-cursor-default-click-outline</v-icon>
      <span v-if="width > 1600">Start Tour</span>
      <span v-else>Tour</span>
    </v-btn>
    <v-btn
      color="white"
      variant="text"
      @click="showDatasets = true"
    >
      <v-icon start>mdi-database</v-icon>
      Data Sources
    </v-btn>

    <v-divider vertical class="ml-2 mr-4"></v-divider>

    <v-btn
      color="white"
      variant="outlined"
      href="https://aktemp.uaa.alaska.edu"
      target="_blank"
      size="small"
    >
      <v-icon start>mdi-arrow-left</v-icon>
      Back to AKTEMP
    </v-btn>
  </v-app-bar>
  <v-container fluid style="background-color: #f5f5f5;" class="fill-height align-start">
    <!-- Welcome Dialog -->
    <v-dialog v-model="showWelcome" max-width="1000">
      <v-card>
        <v-card-title class="text-h4 font-weight-bold primary--text pa-4 ml-2">
          Explore the Stream Temperatures of Alaska
        </v-card-title>
        <v-divider class="mb-4"></v-divider>
        <v-card-text>
          <v-row>
            <v-col cols="12" md="6">
              <p class="text-h6 font-weight-medium mb-4">Uncover water temperature trends and patterns in Alaska's streams and rivers.</p>
              <v-list class="mb-4">
                <v-list-item v-for="(feature, index) in welcomeFeatures" :key="index" :prepend-icon="feature.icon" class="my-2">
                  <v-list-item-title class="font-weight-medium">{{ feature.title }}</v-list-item-title>
                  <div class="text-body-2">{{ feature.description }}</div>
                </v-list-item>
              </v-list>
              <div class="text-body-2">
                <i>Data Sources:</i> Water temperature data from AKTEMP, U.S. Geological Survey, and National Park Service. Air temperature data from Daymet. <a href="#" @click.prevent="showWelcome = false; showDatasets = true">Click here</a> to learn more about the data.
              </div>
            </v-col>
            <v-col cols="12" md="6">
              <v-img src="/img/maddox-furlong-z3lsfr6jDF8-unsplash.jpg" height="400" cover class="rounded-lg" alt="A river in Alaska with snow-capped mountains in the background">
                <template v-slot:placeholder>
                  <v-row class="fill-height ma-0" align="center" justify="center">
                    <v-progress-circular indeterminate color="grey lighten-5"></v-progress-circular>
                  </v-row>
                </template>
              </v-img>
              <div class="text-caption text-right mt-1">
                Photo by <a href="https://unsplash.com/photos/a-lake-surrounded-by-trees-and-mountains-z3lsfr6jDF8" target="_blank" rel="noopener noreferrer">Maddox Furlong on Unsplash</a>
              </div>
            </v-col>
          </v-row>
        </v-card-text>
        <v-divider></v-divider>
        <v-card-actions class="pa-4">
          <v-spacer></v-spacer>
          <v-btn variant="elevated" color="primary" @click="startTour" class="mr-4 px-4">
            <v-icon start>mdi-map-marker-path</v-icon>
            Take a Tour
          </v-btn>
          <v-btn variant="outlined" color="secondary" @click="showWelcome = false" class="px-4">
            <v-icon start>mdi-compass</v-icon>
            Start Exploring
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Data Sources Dialog -->
    <v-dialog v-model="showDatasets" max-width="800">
      <v-card>
        <v-toolbar color="grey-lighten-2" flat density="compact">
          <v-toolbar-title class="text-h5">Data Sources</v-toolbar-title>
        </v-toolbar>
        <v-card-text>
          <div class="text-h6">Water Temperature Data</div>
          <p>A daily water temperature dataset from 1980 to present was compiled from the following data sources:</p>
          <ul class="ml-8 my-4">
            <li><strong>AKTEMP:</strong> <a href="https://aktemp.uaa.alaska.edu" target="_blank">https://aktemp.uaa.alaska.edu</a></li>
            <li><strong>U.S. Geological Survey National Water Information System (NWIS):</strong> <a href="https://waterdata.usgs.gov/nwis" target="_blank">https://waterdata.usgs.gov/nwis</a></li>
            <li><strong>National Park Service (NPS) Aquarius Web Portal:</strong> <a href="https://irma.nps.gov/aqwebportal" target="_blank">https://irma.nps.gov/aqwebportal</a></li>
          </ul>

          <p>This application only shows data from stations located on streams and rivers (lakes and reservoirs are excluded) with at least 180 days of data.</p>

          <div class="text-h6 mt-4">Air Temperature Data</div>
          <p>Air temperature data was obtained from <a href="https://daymet.ornl.gov" target="_blank">Daymet</a>, which provides a 1-km gridded dataset of daily weather data. Air temperature at each station was extracted from the Daymet tiles based on the station's latitude and longitude. Note that Daymet releases new data on an annual cycle, and therefore <b>air temperature data for the current year will not be available until sometime the following year</b>.</p>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn color="primary" text @click="showDatasets = false">Close</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-row>
      <!-- Stations -->
      <v-col :cols="lgAndUp && isCollapsed ? '1' : '12'" :lg="lgAndUp && isCollapsed ? '1' : '5'" :xl="lgAndUp && isCollapsed ? '1' : '4'">
        <v-card :elevation="4" :loading="loadingStations">
          <v-toolbar color="grey-lighten-2" flat density="compact">
            <template v-if="!lgAndUp || !isCollapsed">
              <v-toolbar-title>Stations</v-toolbar-title>
              <v-spacer></v-spacer>
            </template>
            <v-btn
              v-if="!isCollapsed"
              color="default"
              :icon="lgAndUp ? 'mdi-arrow-collapse-left' : 'mdi-arrow-collapse-up'"
              @click="isCollapsed = !isCollapsed"
              size="x-small"
              class="mr-2"
            ></v-btn>
            <v-btn
              v-else
              :icon="lgAndUp ? 'mdi-arrow-collapse-right' : 'mdi-arrow-collapse-down'"
              color="default"
              @click="isCollapsed = !isCollapsed"
              size="x-small"
              :class="lgAndUp ? 'mx-auto' : 'mr-2'"
            ></v-btn>
          </v-toolbar>

          <div v-show="!isCollapsed">
            <v-divider></v-divider>

            <v-card-text>
              <div style="width:100%;height:440px" data-step="stations-map">
                <!-- <StationMap
                  :stations="filteredStations"
                  :selected="selectedStations"
                  :selected-basin="selectedBasin"
                  :basin-layer="selectedBasinLayer"
                  @select="selectStation"
                >
                </StationMap> -->
                <StationMap
                  :stations="filteredStations"
                  :selected="selectedStations"
                  :selected-basin="selectedBasin"
                  @select="selectStation"
                  @select-basin="selectBasin"
                >
                </StationMap>
              </div>
            </v-card-text>

            <v-divider></v-divider>

            <div class="pa-4" data-step="selected-stations">
              <div
                v-if="selectedStations.length === 0"
                class="text-overline text-primary font-weight-bold"
              >
                Select a station on the map or table below.
              </div>

              <div v-else>
                <div class="d-flex align-center mb-2">
                  <div class="text-overline text-primary font-weight-bold">
                    Selected Stations ({{ selectedStations.length }} / {{ maxSelected }})
                  </div>
                  <v-spacer></v-spacer>
                  <v-btn size="small" variant="outlined" v-if="selectedStations.length > 0" @click="clearSelection">
                    <v-icon start>mdi-close</v-icon>
                    Unselect All
                  </v-btn>
                </div>
                <div>
                  <v-alert
                    v-for="station in selectedStations"
                    :key="station.station_id"
                    :color="station.color"
                    variant="tonal"
                    density="compact"
                    class="mb-2"
                  >
                    <div class="d-flex mb-n2">
                      <div class="font-weight-bold">{{ station.provider_station_code }}:{{ station.waterbody_name || 'Unknown Waterbody' }}</div>
                      <v-spacer></v-spacer>
                      <v-btn
                        icon="mdi-close"
                        size="x-small"
                        variant="text"
                        @click="selectStation(station)"
                      ></v-btn>
                    </div>
                    <div class="text-caption">
                      {{ station.provider_name }}
                    </div>
                    <div class="d-flex align-end justify-space-between">
                      <div class="text-caption">
                        {{ station.start }} to {{ station.end }} | {{ station.n.toLocaleString() }} daily values
                      </div>

                      <div class="text-caption">
                        <v-btn
                          prepend-icon="mdi-open-in-new"
                          variant="text"
                          size="x-small"
                          :href="station.url"
                          target="_blank"
                          class="text-decoration-none"
                        >
                          View on {{ station.dataset }}
                        </v-btn>
                      </div>
                    </div>
                  </v-alert>
                </div>
              </div>
            </div>

            <v-alert
              type="error"
              variant="tonal"
              density="compact"
              border="start"
              icon="mdi-alert"
              closable
              class="mx-4 mb-4"
              v-if="selectedStations.length >= maxSelected"
            >
              Maximum of {{ maxSelected }} stations selected. Unselect one to select another.
            </v-alert>

            <v-divider></v-divider>

            <div class="d-flex pr-4">
              <v-text-field
                v-model="filterSearch"
                label="Search Stations"
                prepend-inner-icon="mdi-magnify"
                variant="underlined"
                hide-details
                single-line
                clearable
                class="px-4"
                data-step="station-search"
              ></v-text-field>

              <div class="py-4">
                <v-menu v-model="showFilters" :close-on-content-click="false" location="end" offset="15">
                  <template v-slot:activator="{ props }">
                    <v-btn
                      :color="filtersEnabled ? 'warning' : 'default'"
                      variant="outlined"
                      size="small"
                      v-bind="props"
                      data-step="station-filter"
                    >
                      <v-icon start>mdi-filter-outline</v-icon>
                      Filters
                    </v-btn>
                  </template>
                  <v-sheet style="width:350px">
                    <div class="pa-4 text-h6">Station Filters</div>

                    <v-divider></v-divider>

                    <div class="px-4 pt-4">
                      <!-- <v-select
                        v-model="selectedBasinLayer"
                        :items="basinLayerOptions"
                        item-title="label"
                        item-value="value"
                        label="Basins Layer"
                        density="compact"
                        variant="outlined"
                        clearable
                        hint="Select a layer, then click a basin on the map to filter for stations within that basin."
                        persistent-hint
                        class="mb-4"
                      ></v-select> -->
                      <v-text-field
                        v-model="filterBefore"
                        clearable
                        label="Observations Before (YYYY-MM-DD)"
                        placeholder="YYYY-MM-DD"
                        variant="outlined"
                        density="compact"
                        persistent-hint
                        hint="Filter stations with data before this date."
                        class="mb-4"
                      ></v-text-field>
                      <v-text-field
                        v-model="filterAfter"
                        clearable
                        label="Observations After (YYYY-MM-DD)"
                        placeholder="YYYY-MM-DD"
                        variant="outlined"
                        density="compact"
                        persistent-hint
                        hint="Filter stations with data after this date."
                        class="mb-4"
                      ></v-text-field>
                      <v-text-field
                        v-model="filterCount"
                        clearable
                        label="Minimum # of Daily Observations"
                        variant="outlined"
                        density="compact"
                        type="number"
                        persistent-hint
                        hint="Filter stations with at least this many daily values."
                        class="mb-4"
                      ></v-text-field>
                      <v-checkbox
                        v-model="filterSelected"
                        label="Show Selected Only"
                        hint="Show only stations that are currently selected will be shown in the table and map."
                        persistent-hint
                        density="compact"
                        class="mb-4"
                      ></v-checkbox>
                    </div>

                    <v-divider></v-divider>

                    <div class="d-flex pa-4">
                      <v-btn variant="outlined" aria-label="Clear all station filters" @click="resetFilters">
                        <v-icon start>mdi-refresh</v-icon> Clear All
                      </v-btn>
                      <v-spacer></v-spacer>
                      <v-btn variant="outlined" aria-label="Close station filters menu" @click="showFilters = false">
                        <v-icon start>mdi-close</v-icon> Close
                      </v-btn>
                    </div>
                  </v-sheet>
                </v-menu>
              </div>
            </div>

            <div class="d-flex flex-wrap pa-2 align-center">
              <div class="text-overline text-primary font-weight-bold mx-2" v-if="activeFilters.length > 0">
                Active Filters:
              </div>
              <v-chip
                v-for="filter in activeFilters"
                :key="filter.type"
                class="ma-1"
                closable
                variant="outlined"
                color="warning"
                @click:close="removeFilter(filter.type)"
              >
                {{ filter.label }}&nbsp;<b>{{ filter.value }}</b>
              </v-chip>
            </div>

            <div data-step="stations-table">
              <v-data-table
                v-model="selectedStations"
                :headers="headers"
                :items="filteredStations"
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
            </div>
          </div>
        </v-card>
      </v-col>

      <!-- Charts -->
      <v-col cols="12" :lg="isCollapsed ? '11' : '7'" :xl="isCollapsed ? '11' : '8'">
        <v-row class="mb-0">
          <v-col cols="12">
            <!-- Time Series -->
            <v-card data-step="timeseries" :elevation="4" :loading="loadingData">
              <v-toolbar color="grey-lighten-2" flat density="compact">
                <v-toolbar-title>Time Series</v-toolbar-title>
                <v-spacer></v-spacer>
                <v-btn
                  icon="mdi-help-circle-outline"
                  variant="text"
                  @click="showTimeseriesHelp = true"
                >
                </v-btn>
                <v-dialog v-model="showTimeseriesHelp" max-width="800">
                  <v-card>
                    <v-card-title class="text-h5 px-6 mt-1">
                      Time Series Chart
                    </v-card-title>
                    <v-divider></v-divider>
                    <v-card-text>
                      <p>This chart displays daily mean water temperatures over time for the selected stations.</p>
                      <ul class="ml-8 mt-4">
                        <li>Each line represents a different station.</li>
                        <li>Hover over points to see detailed information.</li>
                        <li>Use the bottom slider or click and drag on the main chart area to zoom in on specific time periods.</li>
                        <li>Use the Zoom preset buttons in the top left corner to zoom to specific time ranges, or return to the full range (All).</li>
                        <li>Click on a station in the legend to hide it.</li>
                      </ul>
                    </v-card-text>
                    <v-divider></v-divider>
                    <v-card-actions>
                      <v-spacer></v-spacer>
                      <v-btn color="primary" text @click="showTimeseriesHelp = false">Close</v-btn>
                    </v-card-actions>
                  </v-card>
                </v-dialog>
              </v-toolbar>
              <div class="d-flex mx-4 align-center flex-wrap">
                <div class="d-flex align-center my-2 mr-2">
                  <div class="text-subtitle-2 mr-2">Average By:</div>
                  <v-btn-toggle
                    v-model="selectedAggregation"
                    density="compact"
                    class="mx-2"
                    variant="outlined"
                    mandatory
                    style="height:42px;"
                  >
                    <v-btn
                      v-for="agg in aggregationOptions"
                      :key="agg.value"
                      :value="agg.value"
                    >
                      {{ agg.label }}
                    </v-btn>
                  </v-btn-toggle>
                </div>
                <div class="d-flex align-center my-2 mr-2" v-if="selectedAggregation === 'season'">
                  <div class="text-subtitle-2 mr-2">
                    <v-icon start>mdi-arrow-right</v-icon>
                    Define Season:
                  </div>
                  <v-select
                    v-model="startMonth"
                    :items="monthOptions"
                    item-title="label"
                    item-value="value"
                    placeholder="Start Month"
                    class="mx-2"
                    style="max-width: 200px"
                    density="compact"
                    variant="outlined"
                    hide-details
                  ></v-select>
                  <div class="text-subtitle-2 mx-2">to</div>
                  <v-select
                    v-model="endMonth"
                    :items="monthOptions"
                    item-title="label"
                    item-value="value"
                    placeholder="End Month"
                    class="mx-2"
                    style="max-width: 200px"
                    density="compact"
                    variant="outlined"
                    hide-details
                  ></v-select>
                </div>
                <v-spacer></v-spacer>
                <div class="d-flex align-center my-2 text-caption" v-if="selectedAggregation !== 'day'">
                  <v-alert
                    color="grey-darken-2"
                    density="compact"
                    class="text-caption"
                    variant="tonal"
                  >
                    <v-icon start>mdi-alert</v-icon>
                    Only
                    <span v-if="selectedAggregation === 'month'">months</span>
                    <span v-else>years</span>
                    with at least 75% of daily values <span v-if="selectedAggregation === 'season'">during the selected season</span> are shown.
                  </v-alert>
                </div>
              </div>

              <v-divider></v-divider>

              <div class="mx-4">
                <TimeseriesChart
                  :series="aggregatedSeries"
                  :loading="loadingData"
                  :aggregation="selectedAggregation"
                  :aggregation-label="timeAggregationLabel"
                  @zoom="onTimeseriesZoom"
                />
              </div>

              <v-divider></v-divider>
              <div class="d-flex mx-4 my-2">
                <v-spacer></v-spacer>
                <div class="d-flex align-center">
                  <v-btn
                    color="primary"
                    variant="outlined"
                    prepend-icon="mdi-download"
                    size="small"
                    @click="downloadData"
                    :disabled="selectedStations.length === 0"
                  >
                    Download Data
                  </v-btn>
                </div>
              </div>
            </v-card>
          </v-col>
        </v-row>

        <v-row class="mt-0">
          <v-col cols="12" md="6">
            <!-- Seasonality -->
            <v-card data-step="seasonal" :elevation="4" :loading="loadingData">
              <v-toolbar color="grey-lighten-2" flat density="compact">
                <v-toolbar-title>Seasonality</v-toolbar-title>
                <v-spacer></v-spacer>
                <v-btn
                  icon="mdi-help-circle-outline"
                  variant="text"
                  @click="showSeasonalHelp = true"
                >
                </v-btn>
                <v-dialog v-model="showSeasonalHelp" max-width="800">
                  <v-card>
                    <v-card-title class="text-h5 px-6 mt-1">Seasonality Chart</v-card-title>
                    <v-divider></v-divider>
                    <v-card-text>
                      <p class="mb-4">This chart displays seasonal changes in water temperature.</p>
                      <p class="mb-4">
                        By default, the chart shows the <b>mean and range of water temperatures on each day of the year</b> and at each station (one line per station).
                      </p>
                      <p>
                        Click the <b>"Show Individual Years"</b> switch to see the water temperature for each individual year (one line per year, multiple years per station).
                      </p>
                    </v-card-text>
                    <v-divider></v-divider>
                    <v-card-actions>
                      <v-spacer></v-spacer>
                      <v-btn color="primary" text @click="showSeasonalHelp = false">Close</v-btn>
                    </v-card-actions>
                  </v-card>
                </v-dialog>
              </v-toolbar>
              <SeasonalChart :series="dailyFilteredSeries" :loading="loadingData" />
            </v-card>
          </v-col>
          <v-col cols="12" md="6">
            <!-- Air vs Water Temp -->
            <v-card data-step="scatter" :elevation="4" :loading="loadingData">
              <v-toolbar color="grey-lighten-2" flat density="compact">
                <div class="flex-grow-1 pl-4">
                  <v-toolbar-title>Air vs Water Scatterplot</v-toolbar-title>
                </div>
                <v-btn
                  icon="mdi-help-circle-outline"
                  variant="text"
                  @click="showScatterHelp = true"
                >
                </v-btn>
                <v-dialog v-model="showScatterHelp" max-width="800">
                  <v-card>
                    <v-card-title class="text-h5 px-6 mt-1">Air vs. Water Temperature Scatterplot</v-card-title>
                    <v-divider></v-divider>
                    <v-card-text>
                      <p>This chart shows the relationship between daily mean air and water temperatures.</p>
                      <ul class="ml-8 my-4">
                        <li>Hover over points to see detailed information.</li>
                        <li>Click and drag to zoom in.</li>
                      </ul>
                      <p>Air temperature data is obtained from <a href="https://daymet.ornl.gov/" target="_blank">Daymet</a>, which is currently available through calendar year {{ config.daymet.last_year }}. Any more recent water temperature data will not be shown in this chart until the next year of Daymet data becomes available (sometime in the following year).</p>
                    </v-card-text>
                    <v-divider></v-divider>
                    <v-card-actions>
                      <v-spacer></v-spacer>
                      <v-btn color="primary" text @click="showScatterHelp = false">Close</v-btn>
                    </v-card-actions>
                  </v-card>
                </v-dialog>
              </v-toolbar>
              <ScatterChart :series="dailyFilteredSeries" :loading="loadingData" :config="config" />
            </v-card>
          </v-col>
        </v-row>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import { DateTime } from 'luxon'
import { driver } from 'driver.js'
import { useDisplay } from 'vuetify'
import { groups } from 'd3-array'
import { debounce, mean } from 'lodash'

import StationMap from '@/components/StationMap'
import TimeseriesChart from '@/components/TimeseriesChart'
import SeasonalChart from '@/components/SeasonalChart'
import ScatterChart from '@/components/ScatterChart'
import { downloadCSV } from '@/lib/download'

const { width, lgAndUp } = useDisplay()

// REFS
const loadingStations = ref(false)
const loadingData = ref(false)
const isCollapsed = ref(false)

const showWelcome = ref(true)
const showDatasets = ref(false)
const showTimeseriesHelp = ref(false)
const showSeasonalHelp = ref(false)
const showScatterHelp = ref(false)

const stations = ref([])
const selectedStations = ref([])
const selectedBasin = ref(null)
const timeRange = ref(null)

const maxSelected = 4
const showFilters = ref(false)
const filterSearch = ref('')
const filterSelected = ref(false)
const filterAfter = ref('')
const filterBefore = ref('')
const filterCount = ref(null)

const config = ref({
  daymet: { last_year: 2023 },
  last_updated: (new Date()).toISOString()
})

const debouncedSearch = ref('')

// Create debounced watcher
watch(filterSearch, debounce((newValue) => {
  debouncedSearch.value = newValue
}, 300))

// FILTERS
const filtersEnabled = computed(() => {
  return filterAfter.value || filterBefore.value || filterCount.value
})

const activeFilters = computed(() => {
  const filters = []

  if (selectedBasin.value) {
    filters.push({
      type: 'basin',
      label: 'Basin: ',
      value: `${selectedBasin.value}`
    })
  }

  if (filterBefore.value) {
    filters.push({
      type: 'before',
      label: 'Start <=',
      value: filterBefore.value
    })
  }

  if (filterAfter.value) {
    filters.push({
      type: 'after',
      label: 'End >= ',
      value: filterAfter.value
    })
  }

  if (filterCount.value) {
    filters.push({
      type: 'count',
      label: 'Count >= ',
      value: filterCount.value
    })
  }

  if (filterSelected.value) {
    filters.push({
      type: 'selected',
      label: 'Selected Stations Only',
      value: ''
    })
  }

  return filters
})

function removeFilter(filterType) {
  switch (filterType) {
    case 'basin':
      selectedBasin.value = null
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
  selectedBasin.value = null
}

function isStationFilteredBySearch (station, search) {
  return ['station_code', 'waterbody_name', 'provider_code'].some(key =>
    station[key]?.toLowerCase().includes(search.toLowerCase())
  )
}

const filteredStations = computed(() => {
  let selectedBasinKey = null
  if (selectedBasin.value) {
    selectedBasinKey = `huc${selectedBasin.value.length}`
  }
  return stations.value.filter(station => {
    return (!filterSelected.value || station.isSelected) &&
      (!debouncedSearch.value || isStationFilteredBySearch(station, debouncedSearch.value)) &&
      (!filterBefore.value || station.start <= filterBefore.value) &&
      (!filterAfter.value || station.end >= filterAfter.value) &&
      (!filterCount.value || station.n >= parseInt(filterCount.value, 10)) &&
      (!selectedBasin.value || station[selectedBasinKey] === selectedBasin.value)
  })
})

// TABLE
const headers = [
  {
    title: 'Provider',
    sortable: true,
    value: 'provider_code',
    nowrap: false,
    maxWidth: '250px'
  },
  {
    title: 'Station',
    sortable: true,
    value: 'station_code',
    nowrap: false,
    maxWidth: '250px'
  },
  {
    title: 'Waterbody',
    sortable: true,
    value: 'waterbody_name',
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
    width: '110px'
   }
]

// COLORS
const defaultColors = [
  '#e41a1c',
  '#377eb8',
  '#4daf4a',
  '#984ea3',
  '#ff7f00',
  '#ffff33',
  '#a65628',
  '#f781bf',
  '#999999'
]
let colors = defaultColors.slice()

// MOUNTED
onMounted(async () => {
  stations.value = await fetchStations()
  config.value = await fetchConfig()
})

// SELECTIONS
async function selectStation (station) {
  if (selectedStations.value.some(d => d.station_id === station.station_id)) {
    colors.unshift(station.color)
    station.isSelected = false
    selectedStations.value = selectedStations.value.filter(d => d.station_id !== station.station_id)
  } else {
    if (selectedStations.value.length >= maxSelected) {
      alert(`You can only select up to ${maxSelected} stations. Unselect one to select another.`)
      return
    }
    station.isSelected = true
    station.data = await fetchData(station)
    station.color = colors.shift()
    selectedStations.value.push(station)
  }
}

const selectedAggregation = ref('day')

const aggregationOptions = [
  { label: 'Day', value: 'day' },
  { label: 'Month', value: 'month' },
  { label: 'Season', value: 'season' }
]

const dailySeries = computed(() => {
  return selectedStations.value.map(station => {
    const rawData = station.data.map(d => ({
      millis: DateTime.fromISO(d.date, { zone: 'US/Alaska' }).toMillis(),
      date: d.date,
      year: +d.date.slice(0, 4),
      month: +d.date.slice(5, 7),
      temp_c: d.temp_c,
      airtemp_c: d.airtemp_c,
      station_id: station.provider_station_code
    }))

    return {
      station_id: `${station.provider_station_code}:${station.waterbody_name}`,
      color: station.color,
      station,
      showInNavigator: true,
      data: rawData
    }
  })
})

const dailyFilteredSeries = computed(() => {
  return dailySeries.value.map(s => {
    return {
      ...s,
      data: s.data.filter(d => {
        if (!timeRange.value) return true
        return d.millis >= (timeRange.value[0]).valueOf() && d.millis <= (timeRange.value[1]).valueOf()
      })
    }
  })
})

const aggregatedSeries = computed(() => {
  return dailySeries.value.map(series => {
    const { data, station } = series
    let aggregatedData
    switch (selectedAggregation.value) {
      case 'month':
        aggregatedData = aggregateByMonth(station.provider_station_code, data)
        break
      case 'season':
        aggregatedData = aggregateBySeason(station.provider_station_code, data, selectedMonths.value)
        break
      default:
        aggregatedData = data
    }

    return {
      station_id: `${station.provider_station_code}:${station.waterbody_name}`,
      color: station.color,
      station,
      showInNavigator: true,
      data: aggregatedData
    }
  })
})

function aggregateByMonth(station_id, data) {
  // Require 75% of 30 days = 23 days minimum
  const MIN_DAYS = 23

  const grouped = groups(data, d => d.date.slice(0, 7))
  return grouped.map(([date, temps]) => ({
    station_id,
    millis: DateTime.fromISO(`${date}-01`).toMillis(),
    date,
    temp_c: temps.length >= MIN_DAYS ? mean(temps.map(d => d.temp_c)) : null,
    year: +date.slice(0, 4),
    n: temps.length
  }))
}

function aggregateBySeason(station_id, data, months) {
  // Calculate minimum days based on number of selected months
  const daysPerMonth = 30
  const totalDays = selectedMonths.value.length * daysPerMonth
  const MIN_DAYS = Math.round(totalDays * 0.75)

  const seasonData = data.filter(d => months.includes(+d.date.slice(5, 7)))
  const grouped = groups(seasonData, d => d.date.slice(0, 4))

  return grouped.map(([year, temps]) => ({
    station_id,
    millis: DateTime.fromISO(`${year}-01-01`).toMillis(),
    date: `${year}-01-01`,
    temp_c: temps.length >= MIN_DAYS ? mean(temps.map(d => d.temp_c)) : null,
    year: +year,
    n: temps.length
  }))
}

async function selectBasin (basinId) {
  if (!basinId || basinId === selectedBasin.value) {
    selectedBasin.value = null
    return
  }
  selectedBasin.value = basinId
}

function clearSelection () {
  selectedStations.value.forEach(d => {
    d.isSelected = false
  })
  selectedStations.value.length = 0
  colors = defaultColors.slice()
}

function onTimeseriesZoom (range) {
  timeRange.value = range
}

// FETCH
async function fetchConfig() {
  try {
    const response = await fetch(`data/config.json`)
    if (!response.ok) {
      alert('Error loading configuration')
      return config.value
    }
    const json = await response.json()
    return json
  } catch (error) {
    alert('Error loading configuration')
    return { daymet: { last_year: new Date().getFullYear() - 1 } }
  }
}

async function fetchStations() {
  loadingStations.value = true
  try {
    const response = await fetch(`data/stations.json`)
    if (!response.ok) {
      alert('Error loading stations')
      return []
    }
    const json = await response.json()
    json.sort((a, b) => a.provider_station_code.localeCompare(b.provider_station_code))
    return json
  } catch (error) {
    alert('Error loading stations')
    return []
  } finally {
    loadingStations.value = false
  }
}

async function sleep (ms) {
  await new Promise(resolve => setTimeout(resolve, ms))
}

async function fetchData(station) {
  if (station.data) return station.data
  loadingData.value = true
  await nextTick()

  try {
    const response = await fetch(`data/stations/${station.filename}`)
    if (!response.ok) {
      alert(`Error loading data for station ${station.provider_station_code}`)
      return []
    }
    await sleep(100)
    return await response.json()
  } catch (error) {
    console.error(error)
    alert(`Error loading data for station ${station.provider_station_code}`)
    return []
  } finally {
    loadingData.value = false
  }
}

// TOUR
const driverTour = driver({
  showProgress: true,
  stagePadding: 10,
  steps: [
    {
      element: '[data-step="stations-map"]',
      popover: {
        title: 'Stations Map',
        description: 'This is the stations map. Hover the layers icon to switch basemaps. Click on a station to select it or press Next and we\'ll select the first station for you.',
        onNextClick: (el, step, opts) => {
          if (selectedStations.value.length === 0) {
            selectStation(stations.value[0])
          }
          driverTour.moveNext()
        }
      }
    },
    {
      element: '[data-step="selected-stations"]',
      popover: {
        title: 'Selected Stations',
        description: `Selected stations will show up here. Click the open link icon to visit the website for that station from its original data source. Click the X icon to deselect a station.<br><br>Note you can select up to ${maxSelected} stations at a time.`
      }
    },
    {
      element: '[data-step="stations-table"]',
      popover: {
        title: 'Stations Table',
        description: 'You can also select or unselect stations using the checkbox on each row of the statios table. Sort the table by clicking on the column headers.'
      }
    },
    {
      element: '[data-step="station-search"]',
      popover: {
        title: 'Station Search',
        description: 'Search for specific stations by typing the organization code or station ID. Only stations matching your search will show up in the table below as well as on the map above.'
      }
    },
    {
      element: '[data-step="station-filter"]',
      popover: {
        title: 'Station Filters',
        description: 'Click the Filters button to see more options for filtering the stations by basin, time period, and observation count.'
      }
    },
    {
      element: '[data-step="timeseries"]',
      popover: {
        title: 'Timeseries Chart',
        description: 'This chart shows a timeseries of the daily mean water temperature at each selected station. Zoom in and out by clicking and dragging over the chart area, or using the time range selector at the bottom of the chart. Click the \'All\' button to zoom out to the full time range.'
      }
    },
    {
      element: '[data-step="seasonal"]',
      popover: {
        title: 'Seasonality Chart',
        description: 'This chart shows the changes in water temperature over each year for the selected stations. Hover over the lines to see detailed information.'
      }
    },
    {
      element: '[data-step="scatter"]',
      popover: {
        title: 'Air vs Water Temp Chart',
        description: 'This chart shows the relationship between daily mean air and water temperatures. Click and drag to zoom in.<br><br>Differences in the shape of this relationship indicate different dynamics and thermal regimes at different stations.',
        onNextClick: (el, step, opts) => {
          clearSelection()
          driverTour.moveNext()
        }
      }
    },
    {
      popover: {
        title: 'Tour Complete!',
        description: 'Thanks for taking the tour! All stations have been unselected so you can start fresh.<br><br>Happy exploring!'
      }
    }
  ]
})

const startTour = () => {
  driverTour.drive()
  showWelcome.value = false
}

// WELCOME
const welcomeFeatures = [
  { icon: 'mdi-filter-outline', title: 'Find Stations', description: 'Filter by name, basin, time period, and observation counts' },
  { icon: 'mdi-map-marker-multiple', title: 'Compare Stations', description: `Choose up to ${maxSelected} stations to compare at a time` },
  { icon: 'mdi-chart-line', title: 'Long-term and Seasonal Trends', description: 'Visualize changes over time and seasons' },
  { icon: 'mdi-chart-scatter-plot', title: 'Air / Water Temperature Relationships', description: 'Explore the dynamics between air and water temperatures' },
]

const startMonth = ref(6) // Default to June
const endMonth = ref(8) // Default to August

const selectedMonths = computed(() => {
  const months = []
  if (startMonth.value <= endMonth.value) {
    // Simple case: just get all months between start and end
    for (let m = startMonth.value; m <= endMonth.value; m++) {
      months.push(m)
    }
  } else {
    // Wrapping case: get months from start to 12 and 1 to end
    for (let m = startMonth.value; m <= 12; m++) {
      months.push(m)
    }
    for (let m = 1; m <= endMonth.value; m++) {
      months.push(m)
    }
  }
  return months
})

// Add the months array for the dropdown
const monthOptions = [
  { label: 'January', value: 1 },
  { label: 'February', value: 2 },
  { label: 'March', value: 3 },
  { label: 'April', value: 4 },
  { label: 'May', value: 5 },
  { label: 'June', value: 6 },
  { label: 'July', value: 7 },
  { label: 'August', value: 8 },
  { label: 'September', value: 9 },
  { label: 'October', value: 10 },
  { label: 'November', value: 11 },
  { label: 'December', value: 12 }
]

// Add this computed property
const timeAggregationLabel = computed(() => {
  switch (selectedAggregation.value) {
    case 'month':
      return 'Monthly Mean'
    case 'season': {
      const startLabel = monthOptions.find(m => m.value === startMonth.value).label.substring(0, 3)
      const endLabel = monthOptions.find(m => m.value === endMonth.value).label.substring(0, 3)
      return `${startLabel}-${endLabel} Mean`
    }
    default:
      return 'Daily Mean'
  }
})

function downloadData() {
  downloadCSV(selectedStations.value, config.value.last_updated)
}

</script>

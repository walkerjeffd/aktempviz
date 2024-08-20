<template>
  <LMap ref="map" :zoom="4" :center="[63,-150]" @ready="mapReady">
    <LControlLayers position="topleft"></LControlLayers>
    <LControl position="topright">
      <div class="legend">
        <div class="mb-2">
          <strong>Data Source</strong>
        </div>
        <div style="" class="legend-item">
          <svg width="20" height="20">
            <circle cx="10" cy="10" r="9" stroke="#4075b0" stroke-opacity="0.8" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" fill="#4075b0" fill-opacity="0.5" ></circle>
          </svg>
          <span class="pl-2">AKTEMP</span>
        </div>
        <div class="legend-item">
          <svg width="20" height="20">
            <circle cx="10" cy="10" r="9" stroke="#ee8830" stroke-opacity="0.8" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" fill="#ee8830" fill-opacity="0.5" ></circle>
          </svg>
          <span class="pl-2">NPS</span>
        </div>
        <div class="legend-item">
          <svg width="20" height="20">
            <circle cx="10" cy="10" r="9" stroke="#509e3d" stroke-opacity="0.8" stroke-width="1" stroke-linecap="round" stroke-linejoin="round" fill="#509e3d" fill-opacity="0.5" ></circle>
          </svg>
          <span class="pl-2">USGS</span>
        </div>
      </div>
    </LControl>
    <LTileLayer
        v-for="tile in basemaps"
        :key="tile.name"
        :name="tile.name"
        :visible="tile.visible"
        :url="tile.url"
        :attribution="tile.attribution"
        :options="tile.options"
        layer-type="base"
      ></LTileLayer>
    <LCircleMarker
      v-for="station in props.selected"
      :key="station.properties.station_id"
      :lat-lng="[station.geometry.coordinates[1], station.geometry.coordinates[0]]"
      :radius="10"
      :weight="5"
      :color="station.color"
      @click="emit('select', station)"
    >
      <LTooltip>
        <div>
          <div class="text-body-1 font-weight-bold">{{ station.properties.station_id }}</div>
          <div class="text-body-2">{{ station.properties.start }} to {{ station.properties.end }}</div>
        </div>
      </LTooltip>
    </LCircleMarker>
  </LMap>
</template>

<script setup>
import { ref, watch } from 'vue'
import { LMap, LTileLayer, LCircleMarker, LControlLayers, LControl, LTooltip } from '@vue-leaflet/vue-leaflet'

import { basemaps } from '@/lib/basemaps'

const props = defineProps({
  selected: {
    type: Array,
    default: () => []
  }
})
const emit = defineEmits(['select', 'load'])

const map = ref(null)
const loading = ref(false)

const datasetColors = {
  'AKTEMP': '#4075b0',
  'NPS': '#ee8830',
  'USGS': '#509e3d'
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
        radius: 8,
        weight: 2,
        opacity: 1,
        fillOpacity: 0.5
      })
    },
    onEachFeature: function (feature, layer) {
      layer.bindTooltip(`${stationPopupTable(feature)}`, { sticky: true })
      layer.on({
        click: (e) => {
          const feature = e.target.feature
          emit('select', feature)
        },
        mouseover: () => {
          layer.setStyle({
            radius: 10
          })
        },
        mouseout: () => {
          restyleStationsLayer()
        }
      })
    }
  }
}

async function createLayer (layer) {
  const url = layer.options.url
  const response = await fetch(url)
  const geojson = await response.json()
  geojson.features.forEach(d => {
    d.id = d.properties.station_id
  })
  emit('load', geojson.features)
  return new L.GeoJSON(geojson, layer.options)
}

async function mapReady (map) {
  loading.value = true

  const stationsLayer = await createLayer(stations)
  stations.mapLayer = stationsLayer
  map.addLayer(stationsLayer)

  loading.value = false
}

function stationPopupTable (feature) {
  return `
    <div class="text-body-1 font-weight-bold">${feature.properties.station_id}</div>
    <div class="text-body-2">${feature.properties.start} to ${feature.properties.end}</div>
  `
}

function restyleStationsLayer () {
  if (!stations.mapLayer) return
  stations.mapLayer.setStyle({
    radius: 8,
    opacity: props.selected.length > 0 ? 0.25 : 1,
    fillOpacity: props.selected.length > 0 ? 0.25 : 0.5
  })
}

watch(() => props.selected, (stations) => {
  restyleStationsLayer()
})

</script>

<style>
/* remove the focus ring */
path.leaflet-interactive:focus {
    outline: none;
}

.leaflet-container {
  background-color: white;
}

.legend {
  background: rgba(255, 255, 255, 0.8);
  padding: 10px;
  border-radius: 5px;
  box-shadow: 0 0 15px rgba(0, 0, 0, 0.2);
}

.legend-item {
  display: flex;
  align-items: center;
  margin-bottom: 5px;
}

.legend-item-icon {
  display: inline-block;
  width: 18px;
  height: 18px;
  border-radius: 18px;
  margin-right: 8px;
}
</style>
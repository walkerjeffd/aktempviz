<template>
  <LMap ref="map" :zoom="4" :center="[63,-150]">
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
      :opacity="0.5"
      layer-type="base"
    ></LTileLayer>

    <LCircleMarker
      v-for="station in props.stations"
      :key="station.station_id"
      :lat-lng="[station.latitude, station.longitude]"
      :color="datasetColors[station.dataset]"
      :fill-color="datasetColors[station.dataset]"
      :radius="8"
      :weight="props.selected.length > 0 ? 1 : 1"
      :fill-opacity="0.25"
      pane="markerPane"
      :opacity="props.selected.length > 0 ? 0.5 : 1"
      @click="emit('select', station)"
    >
      <LTooltip>
        <div>
          <div class="text-body-1 font-weight-bold" style="max-width:400px; text-wrap:wrap;">{{ station.station_id }}</div>
          <div>{{ station.start }} to {{ station.end }}<br>{{ station.n.toLocaleString() }} daily values</div>
        </div>
      </LTooltip>
    </LCircleMarker>
    <LCircleMarker
      v-for="station in props.selected"
      :key="station.station_id"
      :lat-lng="[station.latitude, station.longitude]"
      :radius="10"
      :weight="5"
      :color="station.color"
      pane="markerPane"
      @click="emit('select', station)"
    >
      <LTooltip>
        <div>
          <div class="text-body-1 font-weight-bold" style="max-width:300px; text-wrap:wrap;">{{ station.station_id }}</div>
          <div>{{ station.start }} to {{ station.end }}<br>{{ station.n.toLocaleString() }} daily values</div>
        </div>
      </LTooltip>
    </LCircleMarker>

    <LGeoJson
      v-if="basinGeoJson && basinGeoJson.visible && basinGeoJson.data"
      ref="basinRef"
      :geojson="basinGeoJson.data"
      :options="basinGeoJson.options"
      :options-style="basinGeoJson.style"
      pane="overlayPane"
      @click="clickBasinLayer"
    />
    <LGeoJson
      v-if="basinGeoJson.visible && props.selectedBasin"
      :geojson="props.selectedBasin"
      :options="selectedBasinOptions"
      :options-style="selectedBasinStyle"
      pane="overlayPane"
      @click="clickBasinLayer"
    />
  </LMap>
</template>

<script setup>
import { ref } from 'vue'
import { LMap, LTileLayer, LCircleMarker, LGeoJson, LControlLayers, LControl, LTooltip } from '@vue-leaflet/vue-leaflet'

import { basemaps } from '@/lib/basemaps'

const props = defineProps({
  stations: {
    type: Array,
    default: () => []
  },
  selected: {
    type: Array,
    default: () => []
  },
  basinLayer: {
    type: String,
    default: null
  },
  selectedBasin: {
    type: Object,
    default: null
  }
})
const emit = defineEmits(['select', 'select-basin'])

const map = ref(null)
const basinRef = ref(null)

const datasetColors = {
  'AKTEMP': '#4075b0',
  'NPS': '#ee8830',
  'USGS': '#509e3d'
}

watch(() => props.basinLayer, loadBasinLayer, { immediate: true })

const basinGeoJson = ref({
  data: null,
  options: null,
  style: null,
  loading: false
})

const selectedBasinOptions = {
  onEachFeature (feature, layer) {
    layer.bindTooltip(
      basinTooltipContent(feature),
      { permanent: false, sticky: true }
    )
  }
}

const selectedBasinStyle = () => {
  return {
    weight: 2,
    color: 'orangered',
    opacity: 1,
    fillOpacity: 0
  }
}

function basinTooltipContent (feature) {
  return `<span class="text-body-1 font-weight-bold">${feature.properties.name}</span><br>HUC: ${feature.id}`
}

async function loadBasinLayer (basinLayer) {
  if (!basinLayer) {
    // basinGeoJson.value.visible = false
    emit('select-basin')
    return
  }
  basinGeoJson.value.loading = true
  emit('select-basin')
  const response = await fetch(`data/gis/wbd_${basinLayer}.geojson`)
  const data = await response.json()
  basinGeoJson.value.data = data
  basinGeoJson.value.options = {
    onEachFeature: (feature, layer) => {
      layer.bindTooltip(
        basinTooltipContent(feature),
        { permanent: false, sticky: true }
      )
      layer.on({
        mousemove: (evt) => {
          evt.target.setStyle({
            weight: 3,
            color: 'black'
          })
        },
        mouseout: (evt) => {
          evt.target.setStyle({
            weight: 2,
            color: '#777',
          })
        }
      })
    }
  }
  basinGeoJson.value.style = () => {
    return {
      weight: 2,
      color: '#777',
      opacity: 1,
      fillOpacity: 0
    }
  }
  basinGeoJson.value.visible = true
  basinGeoJson.value.loading = false
}

function clickBasinLayer (evt) {
  const feature = evt.layer.feature
  evt.layer.bringToFront()
  emit('select-basin', feature)
}

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
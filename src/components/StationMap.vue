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
        layer-type="base"
      ></LTileLayer>
    <LCircleMarker
      v-for="station in props.stations"
      :key="station.station_id"
      :lat-lng="[station.latitude, station.longitude]"
      :color="datasetColors[station.dataset]"
      :fill-color="datasetColors[station.dataset]"
      :radius="8"
      :weight="2"
      :fill-opacity="0.25"
      :opacity="props.selected.length > 0 ? 0.25 : 1"
      @click="emit('select', station)"
    >
      <LTooltip>
        <div>
          <div class="text-body-1 font-weight-bold" style="max-width:300px; text-wrap:wrap;">{{ station.station_id }}</div>
          <div class="text-body-2"><i>Period</i>: {{ station.start }} to {{ station.end }}</div>
          <div class="text-body-2"><i>Count</i>: {{ station.n.toLocaleString() }}</div>
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
      @click="emit('select', station)"
    >
      <LTooltip>
        <div>
          <div class="text-body-1 font-weight-bold" style="max-width:300px; text-wrap:wrap;">{{ station.station_id }}</div>
          <div class="text-body-2"><i>Period</i>: {{ station.start }} to {{ station.end }}</div>
          <div class="text-body-2"><i>Count</i>: {{ station.n.toLocaleString() }}</div>
        </div>
      </LTooltip>
    </LCircleMarker>
  </LMap>
</template>

<script setup>
import { ref } from 'vue'
import { LMap, LTileLayer, LCircleMarker, LControlLayers, LControl, LTooltip } from '@vue-leaflet/vue-leaflet'

import { basemaps } from '@/lib/basemaps'

const props = defineProps({
  stations: {
    type: Array,
    default: () => []
  },
  selected: {
    type: Array,
    default: () => []
  }
})
const emit = defineEmits(['select'])

const map = ref(null)

const datasetColors = {
  'AKTEMP': '#4075b0',
  'NPS': '#ee8830',
  'USGS': '#509e3d'
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
<template>
  <highcharts :options="settings" ref="chartEl"></highcharts>
</template>
<script setup>
import { onMounted, watch } from 'vue'
import { groups } from 'd3-array'
import { DateTime } from 'luxon'
import { tooltipFormatter } from '@/lib/utils'

const props = defineProps(['series', 'loading'])
const chartEl = ref(null)

watch(() => props.series, update)
watch(() => props.loading, toggleLoading)

onMounted(() => {
  if (props.series) update()
})

function toggleLoading (loading) {
  const chart = chartEl.value.chart
  if (!chart) return

  if (loading) {
    chart.showLoading()
  } else {
    chart.hideLoading()
  }
}

function julianDay (dateString) {
  const d = DateTime.fromISO(dateString)
  return d.diff(d.startOf('year'), 'days').days
}

function update () {
  const chart = chartEl.value.chart
  if (!chart) return

  const stationYearData = props.series.map(s => {
    if (s.data.length === 0) {
      return {
        station_id: s.station_id,
        color: s.color,
        year: null,
        data: [],
        linkedTo: undefined
      }
    }
    const groupedByYear = groups(s.data, d => d.year)
    return groupedByYear.map((d, i) => {
      return {
        station_id: s.station_id,
        color: s.color,
        year: d[0],
        data: d[1].map(d => {
          return {
            ...d,
            x: julianDay(d.date),
            y: d.temp_c
          }
        }),
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
      station_id: d.name,
      data: d.data,
      // showInLegend: d.showInLegend
    }
  })

  chart.update({
    series
  }, true, true)
}

const settings = {
  chart: {
    type: 'line',
    zoomType: 'xy',
    animation: false,
  },
  plotOptions: {
    series: {
      animation: false,
      marker: {
        symbol: 'circle',
        radius: 2
      },
      opacity: 0.5,
      lineWidth: 1,
      states: {
        hover: {
          opacity: 1
        }
      }
    }
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
      text: 'Daily Mean<br>Water Temperature (degC)'
    }
  },
  tooltip: {
    shared: false,
    useHTML: true,
    distance: 32,
    formatter: function () {
      return tooltipFormatter(this.point)
    }
  },
}


</script>
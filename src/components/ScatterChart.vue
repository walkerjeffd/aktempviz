<template>
  <highcharts :options="settings" ref="chartEl"></highcharts>
</template>
<script setup>
import { onMounted, watch } from 'vue'
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

function update () {
  const chart = chartEl.value.chart
  if (!chart) return

  const opacity = Math.sqrt(1 / props.series.length)
  const series = props.series.map(s => {
    return {
      ...s,
      name: s.station_id,
      opacity: opacity > 0.8 ? 0.8 : opacity,
      data: s.data.map(d => ({
        ...d,
        x: d.airtemp_c,
        y: d.temp_c
      }))
    }
  })

  chart.update({
    series
  }, true, true)
}

const settings = {
  chart: {
    type: 'scatter',
    zoomType: 'xy',
    animation: false
  },
  plotOptions: {
    series: {
      opacity: 0.75,
      marker: {
        symbol: 'circle',
        radius: 2
      },
      states: {
        hover: {
          enabled: true,
          opacity: 0.9,
          halo: {
            opacity: 0.5,
          }
        }
      }
    },
  },
  title: {
    text: 'Air vs Water Temperature'
  },
  xAxis: {
    title: {
      text: 'Daily Mean Air Temperature (degC)'
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
    formatter: function () {
      return tooltipFormatter(this.point)
    }
  }
}

</script>
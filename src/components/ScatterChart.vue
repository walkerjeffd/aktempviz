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

  const totalValues = props.series.reduce((acc, s) => acc + s.data.length, 0)
  const opacity = Math.sqrt(2 / Math.log10(totalValues))

  // Get the min and max values across all data points
  const allPoints = props.series.flatMap(s => s.data.filter(d =>
    d.airtemp_c !== undefined && d.temp_c !== undefined
  ))
  const minTemp = Math.min(...allPoints.map(d => Math.min(d.airtemp_c, d.temp_c)))
  const maxTemp = Math.max(...allPoints.map(d => Math.max(d.airtemp_c, d.temp_c)))

  const series = []
  if (props.series.length > 0) {
    series.push({
      type: 'line',
      name: '1:1 Line',
      data: [[minTemp, minTemp], [maxTemp, maxTemp]],
      color: '#666666',
      dashStyle: 'dash',
      enableMouseTracking: false,
      showInLegend: true
    })
  }

  // Map the data series
  series.push(...props.series.map(s => ({
      ...s,
      name: s.station_id,
      opacity: opacity > 0.9 ? 0.9 : opacity,
      data: s.data.filter(d => d.airtemp_c !== undefined && d.temp_c !== undefined).map(d => ({
        ...d,
        x: d.airtemp_c,
        y: d.temp_c
      }))
    }))
  )

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
  lang: {
    noData: 'Select a station to view data'
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
    line: {  // Add specific options for the 1:1 line
      opacity: 0.5,
      lineWidth: 1,
      marker: {
        enabled: false
      }
    }
  },
  title: {
    text: null
  },
  xAxis: {
    title: {
      text: 'Daily Mean Air Temperature (degC)'
    },
    gridLineWidth: 1
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
    positioner: function (labelWidth, labelHeight, point) {
      const chartWidth = this.chart.chartWidth
      const chartHeight = this.chart.chartHeight
      return {
        x: point.plotX < (chartWidth - labelWidth) / 2 ? point.plotX : chartWidth - labelWidth - 10,
        y: chartHeight - labelHeight - 10,
      }
    },
    formatter: function () {
      return tooltipFormatter(this.point)
    }
  }
}
</script>

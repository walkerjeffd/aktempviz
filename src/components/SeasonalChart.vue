<template>
  <div>
    <div class="px-4 d-flex align-center justify-end">
      <v-switch
        v-model="showIndividualYears"
        label="Show Individual Years"
        hide-details
        color="primary"
      ></v-switch>
    </div>
    <highcharts :options="settings" ref="chartEl"></highcharts>
  </div>
</template>

<script setup>
import { onMounted, watch, ref } from 'vue'
import { groups } from 'd3-array'
import { DateTime } from 'luxon'
import * as HighchartsLib from 'highcharts'
import { tooltipFormatter } from '@/lib/utils'

const props = defineProps(['series', 'loading'])
const chartEl = ref(null)
const showIndividualYears = ref(false)

watch(() => props.series, update)
watch(() => props.loading, toggleLoading)
watch(showIndividualYears, update)

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
  const d = DateTime.fromISO(dateString, { zone: 'US/Alaska' })
  return d.diff(d.startOf('year'), 'days').days
}

function update() {
  const chart = chartEl.value.chart
  if (!chart) return

  let series = []
  if (showIndividualYears.value) {
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
          data: d[1].map(d => ({
            ...d,
            x: julianDay(d.date),
            y: d.temp_c
          })),
          linkedTo: i > 0 ? ':previous' : undefined
        }
      })
    })

    series = stationYearData.flat().map(d => ({
      id: `${d.station_id} ${d.year}`,
      name: `${d.station_id}`,
      color: d.color,
      linkedTo: d.linkedTo,
      station_id: d.name,
      data: d.data,
    }))
  } else {
    series = props.series.map(s => {
      if (s.data.length === 0) {
        return {
          station_id: s.station_id,
          color: s.color,
          data: [],
          linkedTo: undefined
        }
      }

      const groupedByJday = groups(s.data, d => julianDay(d.date))
      const data = Array.from(groupedByJday, ([day, values]) => {
        const temps = values.map(v => v.temp_c).filter(t => t !== null && !isNaN(t))
        const mean = temps.reduce((a, b) => a + b, 0) / temps.length
        const min = Math.min(...temps)
        const max = Math.max(...temps)

        return {
          x: Number(day),
          y: mean,
          low: min,
          high: max,
          n: temps.length
        }
      }).sort((a, b) => a.x - b.x)

      const lineSeries = {
        id: `${s.station_id}`,
        name: `${s.station_id}`,
        color: s.color,
        type: 'line',
        zIndex: 1,
        data
      }
      const rangeSeries = {
        ...lineSeries,
        id: `${s.station_id}-range`,
        type: 'arearange',
        fillOpacity: 0.2,
        lineWidth: 0,
        zIndex: 0,
        linkedTo: ':previous',
        enableMouseTracking: false,
        // marker: { enabled: false },
        data: data.map(point => [point.x, point.low, point.high])
      }

      return [lineSeries, rangeSeries]
    }).flat()
  }

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
  lang: {
    noData: 'Select a station to view data'
  },
  plotOptions: {
    series: {
      animation: false,
      marker: {
        symbol: 'circle',
        radius: 2
      },
      opacity: 0.8,
      lineWidth: 1,
      states: {
        hover: {
          opacity: 1
        }
      }
    }
  },
  title: {
    text: null
  },
  xAxis: {
    min: 0,
    max: 365,
    title: {
      text: 'Day of Year'
    },
    gridLineWidth: 1,
    tickPositions: [0, 59, 120, 181, 243, 304, 365],
    labels: {
      formatter: function() {
        const date = new Date(2023, 0, this.value + 1);
        return HighchartsLib.dateFormat('%b', date);
      }
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
    positioner: function (labelWidth, labelHeight, point) {
      const chartWidth = this.chart.chartWidth
      const chartHeight = this.chart.chartHeight
      return {
        x: point.plotX < (chartWidth - labelWidth) * 0.8 ? point.plotX : chartWidth - labelWidth - 10,
        y: chartHeight - labelHeight - 10,
      }
    },
    formatter: function () {
      if (this.series.type === 'arearange') return false
      const point = this.point
      if (showIndividualYears.value) {
        return tooltipFormatter(point)
      } else {
        return `<b>${this.series.name}</b><br/>
                Date: ${HighchartsLib.dateFormat('%b %e', new Date(2023, 0, point.x))}<br/>
                Mean: ${point.y.toFixed(1)}°C<br/>
                Range: ${point.low.toFixed(1)} - ${point.high.toFixed(1)}°C`
      }
    }
  }
}


</script>

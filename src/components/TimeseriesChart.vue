<template>
  <highcharts :constructor-type="'stockChart'" :options="settings" ref="chartEl"></highcharts>
</template>
<script setup>
import { onMounted, watch } from 'vue'

const props = defineProps(['series', 'loading'])
const emit = defineEmits(['zoom'])
const chartEl = ref(null)

watch(() => props.series, update)
watch(() => props.loading, toggleLoading)

onMounted(() => {
  if (props.series) update()
})

function onTimeFilter (event) {
  if (event.min && event.max) {
    emit('zoom', [new Date(event.min), new Date(event.max)])
  }
}

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

  window.chart = chart

  const nPrevious = chart.series.length

  const series = props.series.map(s => {
    return {
      ...s,
      name: s.station_id,
      showInNavigator: true,
      data: s.data.map(d => ({
        ...d,
        x: d.millis,
        y: d.temp_c,
      }))
    }
  })

  chart.update({
    series: []
  }, true, true)
  chart.update({
    series
  }, true, true)

  if (nPrevious === 0) {
    // reset time filter
    chart.xAxis[0].setExtremes(null, null, true, false)
  }
}

function tooltipFormatter(date, points) {
  const rows = points.map(d => `
    <tr>
      <td style="color: ${d.point.color}; padding-right: 10px; font-size: 18px;">&#9679;</td>
      <td style="font-weight: bold; padding-right: 12px;">${d.point.station_id}</td>
      <td style="text-align: right; font-weight: bold;">${d.point.temp_c?.toFixed(1)}</td>
    </tr>
  `).join('');

  return `
    <div style="">
      <div style="font-size: 16px; font-weight: bold; margin-bottom: 10px; color: #333;">${new Date(date).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })}</div>
      <table style="border-collapse: separate; border-spacing: 0 6px; font-size: 14px;">
        <thead>
          <tr>
            <th></th>
            <th style="text-align: left; color: #666; font-weight: normal;">Station</th>
            <th style="text-align: left; color: #666; font-weight: normal;">Water Temp (°C)</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

const settings = {
  chart: {
    height: 500,
    marginLeft: 70,
    zoomType: 'x',
    boost: {
      enabled: false
    }
  },
  title: {
    text: 'Timeseries'
  },
  plotOptions: {
    series: {
      gapSize: 1,
      marker: {
        symbol: 'circle',
        radius: 2
      },
      lineWidth: 1,
    },
  },
  lang: {
    noData: 'No data to display'
  },
  noData: {
    style: {
      fontWeight: 'bold',
      fontSize: '15px',
      color: '#303030'
    }
  },
  loading: {
    style: {
      position: 'absolute',
      backgroundColor: '#ffffff',
      opacity: 1,
      textAlign: 'center'
    }
  },
  legend: {
    enabled: true,
    align: 'right'
  },
  tooltip: {
    shared: false,
    useHTML: true,
    formatter: function () {
      return tooltipFormatter(this.point.date, this.points)
    }
  },
  scrollbar: {
    liveRedraw: true // enable for interactive filtering
  },
  navigator: {
    adaptToUpdatedData: false,
  },
  rangeSelector: {
    selected: 4,
    buttons: [{
      type: 'month',
      count: 1,
      text: '1m',
      title: 'View 1 month'
    }, {
      type: 'month',
      count: 3,
      text: '3m',
      title: 'View 3 months'
    }, {
      type: 'month',
      count: 6,
      text: '6m',
      title: 'View 6 months'
    }, {
      type: 'year',
      count: 1,
      text: '1y',
      title: 'View 1 year'
    }, {
      type: 'all',
      text: 'All',
      title: 'View all'
    }]
  },
  xAxis: {
    ordinal: false,
    minRange: 24 * 3600 * 1000,
    events: {
      afterSetExtremes: onTimeFilter
    }
  },
  yAxis: {
    allowDecimals: false,
    opposite: false,
    startOnTick: false,
    endOnTick: false,
    tickAmount: 8,
    title: {
      text: 'Daily Mean<br>Water Temperature (degC)'
    },
    min: 0
  },
  credits: {
    enabled: false
  },
  series: []
}

</script>
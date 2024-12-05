import { DateTime } from 'luxon'

export function tooltipFormatter ({ station_id, date, temp_c, airtemp_c }) {
  return `<table>
    <tbody>
      <tr>
        <td class="pr-2 text-right">Station</td>
        <td><b>${station_id}</b></td>
      </tr>
      <tr>
        <td class="pr-2 text-right">Date</td>
        <td><b>${DateTime.fromISO(date, { zone: 'US/Alaska' }).toFormat('MMM d, yyyy')}</b></td>
      </tr>
      <tr>
        <td class="pr-2 text-right">Water Temp</td>
        <td><b>${temp_c?.toFixed(1) + '°C'} </b></td>
      </tr>
      <tr>
        <td class="pr-2 text-right">Air Temp</td>
        <td><b>${airtemp_c?.toFixed(1)} °C</b></td>
      </tr>
    </tbody>
  </table>`
}

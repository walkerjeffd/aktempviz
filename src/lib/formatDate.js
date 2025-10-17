import { DateTime } from 'luxon'

export function formatDate (date, format = 'MMM d, yyyy') {
  return DateTime.fromISO(date, { zone: 'US/Alaska' }).toFormat(format)
}
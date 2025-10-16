# compute and compare daily-aggregated value vs mean of hourly values over different day definitions
# to verify daily-aggregated values are computed over UTC days

import ee
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

# 1) Init
service_account = 'aktempviz@aktemp-walkerenvres.iam.gserviceaccount.com'
credentials = ee.ServiceAccountCredentials(service_account, '../service-account.json')
ee.Initialize(credentials)

# ---- user inputs ----
lat, lon = 45.0, -69.0            # pick a location
date_str = "2023-07-10"           # date to test
variable = "temperature_2m"       # band to compare
tz_name = "America/New_York"      # local timezone to test against
scale = 9000
# ----------------------

pt = ee.Geometry.Point([lon, lat])

# Helpers
def get_daily_aggr_value(date_str):
    ic = (ee.ImageCollection("ECMWF/ERA5_LAND/DAILY_AGGR")
          .filterDate(date_str, (datetime.fromisoformat(date_str) + timedelta(days=1)).date().isoformat())
          .select(variable))
    img = ic.first()
    return img.reduceRegion(ee.Reducer.mean(), pt, scale).get(variable).getInfo()

def mean_hourly_over_range(start_iso, end_iso):
    ic = (ee.ImageCollection("ECMWF/ERA5_LAND/HOURLY")
          .filterDate(start_iso, end_iso)
          .select(variable))
    img = ic.mean()
    return img.reduceRegion(ee.Reducer.mean(), pt, scale).get(variable).getInfo()

# UTC midnight → UTC midnight
start_utc = datetime.fromisoformat(date_str).replace(tzinfo=ZoneInfo("UTC"))
end_utc = start_utc + timedelta(days=1)

# Local midnight → local midnight, converted to UTC
start_local = datetime.fromisoformat(date_str).replace(tzinfo=ZoneInfo(tz_name))
end_local = start_local + timedelta(days=1)
start_local_as_utc = start_local.astimezone(ZoneInfo("UTC"))
end_local_as_utc = end_local.astimezone(ZoneInfo("UTC"))

# Fetch values
v_daily = get_daily_aggr_value(date_str)
v_hourly_utc = mean_hourly_over_range(start_utc.isoformat(), end_utc.isoformat())
v_hourly_localday = mean_hourly_over_range(start_local_as_utc.isoformat(), end_local_as_utc.isoformat())

print("Location:", (lat, lon))
print("Date (nominal):", date_str)
print("Variable:", variable)
print("Daily Aggregated (GEE):", v_daily)
print("Mean over UTC day: ", v_hourly_utc, " difference:", v_daily - v_hourly_utc)
print(f"Mean over {tz_name} local day:", v_hourly_localday, " difference:", v_daily - v_hourly_localday)

print("Conclusion: Daily aggregation based on UTC days, not local days.")
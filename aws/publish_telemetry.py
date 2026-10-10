"""Publish simulated plant equipment temperature and output telemetry to AWS IoT Core (topic vn/renewable-carbon/telemetry).

The IoT rule lands each message in S3; Snowpipe loads it into RAW.LIVE_TELEMETRY.
Plant IDs come from RAW.PLANTS (PL-0000..PL-0029). Values are seeded random.
"""
import argparse
import json
import random
from datetime import datetime, timezone


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    iot = boto3.client('iot', region_name=args.region)
    endpoint = iot.describe_endpoint(endpointType='iot:Data-ATS')['endpointAddress']
    data = boto3.client('iot-data', region_name=args.region, endpoint_url=f'https://{endpoint}')
    rng = random.Random(args.seed)
    for _ in range(args.count):
        site = f'PL-{rng.randint(0, 29):04d}'
        alarm = rng.random() < 0.1
        msg = {'site_id': site,
               'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
               'equip_temp_c': round(rng.gauss(82.0 if alarm else 48.0, 4.0), 1),
               'output_pct': round(min(100.0, rng.gauss(35 if alarm else 78, 5)), 1),
               'status': 'ALARM' if alarm else 'NORMAL'}
        data.publish(topic='vn/renewable-carbon/telemetry', qos=1, payload=json.dumps(msg))
    print(f'published {args.count} messages to vn/renewable-carbon/telemetry via {endpoint}')


if __name__ == '__main__':
    main()

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from setup_aws import ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('vn-renewable-carbon', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'vn-renewable-carbon-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'VN_RENEWABLE_CARBON_S3_INT')
        self.assertEqual(n['iot_rule'], 'vn_renewable_carbon_telemetry')

    def test_iot_requests_match_botocore_schema(self):
        import json
        import botocore.session
        from botocore.validate import ParamValidator
        from setup_aws import TOPIC
        session = botocore.session.get_session()
        validator = ParamValidator()
        n = names('vn-renewable-carbon', '123456789012', 'us-west-2')
        rule = {'sql': f"SELECT *, timestamp() AS iot_received_ms FROM '{TOPIC}'", 'awsIotSqlVersion': '2016-03-23',
                'ruleDisabled': False, 'actions': [{'s3': {
                    'roleArn': 'arn:aws:iam::123456789012:role/test', 'bucketName': n['bucket'],
                    'key': 'iot/${timestamp()}-${newuuid()}.json'}}]}
        iot = session.get_service_model('iot').operation_model('CreateTopicRule').input_shape
        report = validator.validate({'ruleName': n['iot_rule'], 'topicRulePayload': rule}, iot)
        self.assertFalse(report.has_errors(), report.generate_report())
        msg = {'site_id': 'PL-0001', 'event_ts': '2026-01-01T00:00:00.000', 'equip_temp_c': 48.0,
               'output_pct': 78.0, 'status': 'NORMAL'}
        data = session.get_service_model('iot-data').operation_model('Publish').input_shape
        report = validator.validate({'topic': TOPIC, 'qos': 1, 'payload': json.dumps(msg).encode()}, data)
        self.assertFalse(report.has_errors(), report.generate_report())

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)


if __name__ == '__main__':
    unittest.main()

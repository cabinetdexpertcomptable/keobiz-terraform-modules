"""Tests for Lambda functions."""
import json
import pytest


class TestAPIFunction:
    def test_health(self):
        from functions.api.handler import handler
        result = handler({"httpMethod": "GET", "path": "/health"}, None)
        assert result["statusCode"] == 200
        assert "healthy" in json.loads(result["body"])["status"]

    def test_get_users(self):
        from functions.api.handler import handler
        result = handler({"httpMethod": "GET", "path": "/users"}, None)
        assert result["statusCode"] == 200


class TestProcessorFunction:
    def test_sqs_message(self):
        from functions.processor.handler import handler
        event = {
            "Records": [{
                "messageId": "1",
                "eventSource": "aws:sqs",
                "body": json.dumps({"type": "test"})
            }]
        }
        result = handler(event, None)
        assert result["statusCode"] == 200


class TestSchedulerFunction:
    def test_cleanup_task(self):
        from functions.scheduler.handler import handler
        result = handler({"task": "cleanup"}, None)
        assert result["statusCode"] == 200

    def test_healthcheck_task(self):
        from functions.scheduler.handler import handler
        result = handler({"task": "healthcheck"}, None)
        body = json.loads(result["body"])
        assert body["result"]["healthy"] == True


import unittest

from circleci_sign_publish_example import hello


class TestHello(unittest.TestCase):
    def test_hello_returns_greeting(self):
        self.assertEqual(hello(), "hello from the CircleCI PyPI publish example")


if __name__ == "__main__":
    unittest.main()

# Benchmarks

## Environment
- Machine:
- macOS:
- Xcode:
- Swift:

## Scenario
- 500 concurrent requests via URLProtocol mock
- Expired token -> 401 -> single-flight refresh -> replay

## Results
- Total runtime:
- Token refresh count:
- Failures:

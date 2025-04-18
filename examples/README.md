# Examples

This directory contains example scripts demonstrating Mongory's features and capabilities.

## Performance Benchmark

`benchmark.rb` demonstrates Mongory's performance characteristics with different data sizes and query complexities.

### Usage

```bash
ruby examples/benchmark.rb
```

### What it tests

1. Simple queries with different data sizes:
   - 1000 records
   - 10000 records
   - 100000 records

2. Complex queries with different data sizes:
   - OR conditions
   - Nested conditions

### Output

The script outputs execution times for each test case, helping you understand:
- How query complexity affects performance
- How data size impacts execution time
- The relative performance of different query types

### Note

Results may vary based on:
- Hardware specifications
- Ruby version
- System load
- Other factors

Run the benchmark in your environment to get accurate performance data for your use case. 
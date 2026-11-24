# Performance & Benchmarks

## Reproducible Benchmarks

Run the included benchmark script in `mongory-rb` to measure `Mongory::Matcher` on your local Ruby runtime:

```bash
ruby script/bench.rb
```

To include the `Mongoid::Matcher` comparison (optional, keeps `mongory` zero-dependency), install `mongoid` in a separate `GEM_PATH`:

```bash
gem install --install-dir /tmp/rb-bench-gems --no-document mongoid
GEM_PATH=/tmp/rb-bench-gems ruby script/bench.rb
```

### Measured Results (Apple M3, macOS arm64, Ruby `4.0.5`, 100,000 records x 5 rounds)

| Case | Plain Ruby `Array#count` | `Mongory::Matcher` (`mongory-core` C99) | `Mongoid::Matcher` (`mongoid 9.1.2`) | `Mongory` vs `Mongoid` |
|---|---:|---:|---:|---:|
| `simple` (`age >= 18`) | `6.31 ms` (`63.1 ns/rec`) | `7.79 ms` (`77.9 ns/rec`) | `322.45 ms` (`3,224.5 ns/rec`) | **41.4x faster** |
| `$or` (`age >= 18` or `status == "active"`) | `7.18 ms` (`71.8 ns/rec`) | `12.74 ms` (`127.4 ns/rec`) | `396.79 ms` (`3,967.9 ns/rec`) | **31.1x faster** |
| `in_array_field` (`tags $in ["ruby", "rust"]`) | `8.53 ms` (`85.3 ns/rec`) | `13.64 ms` (`136.4 ns/rec`) | `430.21 ms` (`4,302.1 ns/rec`) | **31.5x faster** |
| `large_in_500` (`name $in [500 items]`, O(1) hash) | `6.29 ms` (`62.9 ns/rec`) | `11.58 ms` (`115.8 ns/rec`) | `9,735.19 ms` (`97,351.9 ns/rec`) | **840.7x faster** |

> For cross-language benchmarks (`mongory-go`, `mongory-js`, `mongory-py`), see [Mongory Central](https://mongoryhq.github.io/mongory-central/#benchmarks).

## Optimization Tips

- **Reuse `Mongory::Matcher` Instances**: Compile once with `Mongory::Matcher.new(condition)` (or `Mongory.compile(condition)`) and call `#match?` across records to avoid recompiling the condition tree.
- **Priority Ordering & Dynamic Re-Sorting**: Mongory automatically orders cheaper equality/existence checks before regex or array scans, and re-sorts siblings if a lazy array matcher is constructed.
- **Inspect Plans**: Use `.explain` / `.trace` to verify cheap fields short-circuit early.

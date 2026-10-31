# Chart touch performance

The October 31 scrubbing implementation kept raw touch selection in NativeTrends. Each change invalidated the full screen, reevaluating computed diary buckets and nutrient averages repeatedly while Swift Charts handled the gesture.

An isolated optimized model harness using 30 days with eight food entries per day measured one bucket/average aggregation pair at **52.09 ms**. This exceeds a frame budget before chart drawing and understates the original screen's repeated getter reads. It is an aggregation benchmark, not a measured phone frame rate.

The fix places selection in NativeTrendPlot, which receives immutable chart inputs and has no NutrientStore reference. NativeTrends computes buckets and averages once per parent update. The selection subtree looks up existing buckets and normalizes the pointer date to a day/week/month; movement inside the same period does not publish a new selection. Haptics follow period changes. Changes to diary-derived inputs refresh the lookup while retaining the selected period.

Run `npm run test:native` for the regression checks. They cover daily/weekly/monthly boundaries, recorded zero versus missing periods, clearing selection, and 10,000 within-day samples emitting one state change. The selection calculation measured **0.0032 ms/sample** in the Simulator test. This excludes Swift Charts rendering and is not an end-to-end touch-latency comparison with the aggregation benchmark.

The physical iPhone Debug build passed for hands-on touch verification. Release Simulator compilation is checked separately. No automated physical drag/frame-rate claim is made.

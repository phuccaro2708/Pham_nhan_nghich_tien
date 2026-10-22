
## Tổng hợp

| Chiến lược | Seeds | Tới Trúc Cơ | Median (giờ chủ động) | Worst | Best | Thất bại đột phá TB | Tuổi cuối TB |
|---|---|---|---|---|---|---|---|
| casual | 20 | 20/20 | 5.22 | 6.75 | 4.44 | 1.00 | 38.8 |
| optimizer | 20 | 20/20 | 4.70 | 6.12 | 3.95 | 1.00 | 38.5 |
| idle | 20 | 20/20 | 4.01 | 5.02 | 3.51 | 1.00 | 39.3 |

## Mốc thời gian (median, phút chủ động)

| Chiến lược | first_upgrade | luyen_khi_1 | luyen_khi_5 | luyen_khi_9 | truc_co_so |
|---|---|---|---|---|---|
| casual | — | 13.5 | 28.5 | 142.5 | 313.0 |
| optimizer | — | 11.9 | 25.1 | 126.9 | 282.1 |
| idle | — | 5.9 | 18.6 | 116.7 | 240.6 |

## Thời gian theo hành động (median, giây chủ động)

- **casual**: refine_qi 7031s (37%); absorb_qi 6057s (32%); gather_wood 3480s (19%); idle 1502s (8%); train_body 630s (3%); gather_herbs 30s (0%); sense_qi 30s (0%); treat_meridian 20s (0%)
- **optimizer**: refine_qi 7011s (41%); absorb_qi 5938s (35%); gather_wood 3295s (19%); train_body 624s (4%); sense_qi 30s (0%); treat_meridian 20s (0%); gather_herbs 6s (0%)
- **idle**: refine_qi 6949s (48%); absorb_qi 5603s (39%); gather_wood 1565s (11%); train_body 264s (2%); sense_qi 30s (0%); treat_meridian 20s (0%); gather_herbs 6s (0%)

## Tài nguyên bị đốt bởi đột phá thất bại (trung bình mỗi seed)

- **casual**: cultivation 2204, silver 500
- **optimizer**: cultivation 2204, silver 500
- **idle**: cultivation 2204, silver 500

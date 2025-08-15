# Flutter KeyCheck v3 Coverage Report

Generated: 2025-08-15T23:43:41.593416

## Summary

| Metric | Value |
|--------|-------|
| Total Widgets | 156 |
| Widgets with Keys | 148 |
| Coverage | 94.87% |
| Parse Success Rate | 95.2% |

## Detector Performance

| Detector | Hits | Keys Found | Effectiveness |
|----------|------|------------|---------------|
| ValueKeyDetector | 89 | 89 | 100% |
| KeyDetector | 45 | 45 | 100% |
| TestKeyDetector | 14 | 14 | 100% |

## Blind Spots

⚠️ Found 2 widgets without keys:

1. `lib/widgets/custom_button.dart:42` - Container (Missing key in list item)
2. `lib/screens/home_screen.dart:78` - Column (Missing key in stateful widget)

## File Coverage

| File | Widgets | Keys | Coverage |
|------|---------|------|----------|
| lib/main.dart | 12 | 11 | 91.67% |
| lib/widgets/custom_button.dart | 8 | 7 | 87.5% |

## Recommendations

- Add keys to widgets in lists for better performance
- Consider using ValueKey for stateful widgets
- Review blind spots and add appropriate keys

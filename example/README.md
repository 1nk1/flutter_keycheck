# flutter_keycheck Example

This example demonstrates how to use the `flutter_keycheck` CLI tool to validate Flutter automation keys.

## Files

- `expected_keys.yaml` - Example keys configuration file
- `sample_flutter_app/` - Sample Flutter code with keys
- `run_example.sh` - Script to run the validation

## Usage

1. Install the CLI tool:

```bash
dart pub global activate flutter_keycheck
```

1. Run the validation:

```bash
flutter_keycheck --keys expected_keys.yaml --path sample_flutter_app --verbose
```

## Expected Output

The tool will scan the sample Flutter app and report:

- ✅ Found keys and their locations
- ❌ Missing keys that need to be added
- 📦 Dependency status
- 🧪 Integration test setup status

# Niskala Model Gen

**Niskala Model Gen** is a robust Dart code generator that automates the creation of strongly-typed Dart models from IFS Applications Projection metadata. It connects to your IFS environment, fetches metadata, and generates Dart classes for Entities, Functions, Actions, and Enums with full JSON serialization support.

## Features

- **Metadata-Driven Validation**: All models now include a `validate()` method based on OData constraints (`maxLength`, `minimum`, `maximum`, `pattern`).
- **Partial Update Support**: New `toPartialJson()` method enables efficient OData `PATCH` operations by automatically filtering out null fields.
- **Advanced CLI**: New commands like `init` (scaffolding), `--watch` (live regeneration), and `--dry-run` (safe preview).
- **Smart Merge Evolution**: Enhanced `CodeMerger` with automatic stale model import cleanup and standardized sorting (dart -> package -> relative).
- **Modern Engine**: Built with `package:code_builder` for reliable code generation and `package:very_good_analysis` for 100% linter compliance.

## Part-File Architecture

Niskala Model Gen uses a clean, side-by-side file architecture:

```dart
// user_model.dart
import 'package:niskala_model_gen/niskala_model_gen.dart';

part 'user_model.niskala.dart';

class UserModel extends _$UserModel {
  UserModel({super.id, super.name});

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  // Custom logic here

  void myCustomMethod() {
    print('Safety first!');
  }
}
```

## Smart Merging

The generator now supports smart merging of custom code. It uses a single marker `// Custom logic here`.
Everything coded **after** this marker in the main model file is strictly preserved during regeneration.
The generator also performs a smart union of imports, ensuring your custom imports are never lost.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
    niskala_model_gen:
        path: ../Niskala Model Gen
```

### 2. Add generator command to `niskala.yaml`

```yaml
niskala_model_gen:
    version: "v1.0.0"
```

For a complete working example, see the [Niskala Framework Example](../Niskala%20Framework%20Example) directory at the project root.

## Configuration

Create a YAML configuration file (default: `niskala.yaml`) in your project root.

```yaml
# Unified generator configuration
niskala_gen:
    resource_path: metadata
    output: lib

odataEnvironments:
    - name: Development
      baseUrl: https://ifsdev.your-company.co.id
      realms: ifsaaldev
      clientId: IFS_connect
      clientSecret: your_secret

apiDefinitions:
    - projection: PurchaseRequisitionHandling.svc
      method: GET
      endpoint: /PurchaseReqLineNopartSet
    - projection: AnotherProjection.svc
      method: GET
      endpoint: /AnotherEntitySet
```

The generator will look for metadata files (e.g., `PurchaseRequisitionHandling.svc.json`) in the directory specified by `resource_path`. It will **not** attempt to connect to any API.

## Usage

### CLI Usage (Recommended)

Run the generator using `dart run`:

```bash
# Default (looks for niskala.yaml and outputs to 'lib')
dart run niskala_model_gen

# Custom config file
dart run niskala_model_gen --config my_config.yaml

# Enable verbose logging details
dart run niskala_model_gen --verbose

# Show help
dart run niskala_model_gen --help
```

## Requirements

- Dart SDK: >=3.10.4 <4.0.0

## License

MIT License — see [LICENSE](LICENSE) for details.

# 🏗️ FLUTTER KEYCHECK - ARCHITECTURE DIAGRAMS

## CLEAN ARCHITECTURE LAYERS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION LAYER                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   CLI    │  │ Commands │  │Reporters │  │   HTML   │  │Dashboard │   │
│  │  Runner  │  │  (Scan,  │  │  (JSON,  │  │ Premium  │  │Executive │   │
│  │          │  │Validate) │  │   CI)    │  │ Reporter │  │ Reporter │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER (USE CASES)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ AstScannerV3 │  │   Policy     │  │  Duplicate   │  │   Quality    │  │
│  │              │  │  Validator   │  │  Detector    │  │   Scorer     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │     Key      │  │  Workspace   │  │    Stats     │  │   Metrics    │  │
│  │  Detectors   │  │   Scanner    │  │ Calculator   │  │  Collector   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DOMAIN LAYER (ENTITIES)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  ScanResult  │  │   KeyUsage   │  │ FileAnalysis │  │  BlindSpot   │  │
│  │              │  │              │  │              │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ ScanMetrics  │  │ KeyLocation  │  │ HandlerInfo  │  │ Validation   │  │
│  │              │  │              │  │              │  │   Result     │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ▲
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFRASTRUCTURE LAYER                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │    Cache     │  │     Git      │  │   Package    │  │   Storage    │  │
│  │   Manager    │  │   Registry   │  │   Registry   │  │   Registry   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Dependency  │  │    Config    │  │   Analyzer   │  │     File     │  │
│  │    Cache     │  │      V3      │  │Compatibility │  │    System    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## DEPENDENCY FLOW (Following Dependency Inversion Principle)

```
    Presentation Layer
           │
           ▼ (depends on)
    Application Layer
           │
           ▼ (depends on)
      Domain Layer
           ▲ (implements)
           │
    Infrastructure Layer

Note: Infrastructure implements Domain interfaces,
      not the other way around (Dependency Inversion)
```

## DATA FLOW DIAGRAM

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│   User  │────▶│   CLI    │────▶│ Command  │────▶│ Use Case │
└─────────┘     └──────────┘     └──────────┘     └──────────┘
                                                         │
                                                         ▼
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Output │◀────│ Reporter │◀────│  Result  │◀────│  Domain  │
└─────────┘     └──────────┘     └──────────┘     └──────────┘
                                                         ▲
                                                         │
                                                  ┌──────────────┐
                                                  │Infrastructure│
                                                  └──────────────┘
```

## COMPONENT INTERACTION

```
                          flutter_keycheck scan
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
              Parse Args                  Load Config
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                          Create Scanner
                                  │
                ┌─────────────────┼─────────────────┐
                ▼                 ▼                 ▼
          Scan Files      Detect Keys      Analyze AST
                │                 │                 │
                └─────────────────┼─────────────────┘
                                  ▼
                          Build ScanResult
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
              Cache Result               Generate Report
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                              Output
```

## PACKAGE STRUCTURE

```
flutter_keycheck/
│
├── lib/
│   ├── flutter_keycheck.dart          # Public API
│   └── src/
│       ├── models/                    # DOMAIN LAYER
│       │   ├── scan_result.dart
│       │   ├── key_usage.dart
│       │   ├── file_analysis.dart
│       │   ├── blind_spot.dart
│       │   └── validation_result.dart
│       │
│       ├── scanner/                   # USE CASES
│       │   ├── ast_scanner_v3.dart
│       │   ├── key_detectors_v3.dart
│       │   └── workspace_scanner.dart
│       │
│       ├── commands/                  # PRESENTATION
│       │   ├── scan_command_v3.dart
│       │   ├── validate_command_v3.dart
│       │   └── base_command_v3.dart
│       │
│       ├── reporter/                  # PRESENTATION
│       │   ├── base_reporter.dart
│       │   ├── coverage_reporter.dart
│       │   └── premium_dashboard_reporter.dart
│       │
│       ├── cli/                       # PRESENTATION
│       │   └── cli_runner.dart
│       │
│       ├── cache/                     # INFRASTRUCTURE
│       │   ├── cache_manager.dart
│       │   └── dependency_cache.dart
│       │
│       ├── registry/                  # INFRASTRUCTURE
│       │   ├── key_registry_v3.dart
│       │   └── git_registry.dart
│       │
│       ├── config/                    # INFRASTRUCTURE
│       │   └── config_v3.dart
│       │
│       └── policy/                    # USE CASES
│           ├── policy_engine_v3.dart
│           └── policy_validator.dart
│
├── bin/
│   └── flutter_keycheck.dart         # Entry point
│
└── test/
    ├── unit/                          # Unit tests
    ├── integration/                   # Integration tests
    └── e2e/                          # End-to-end tests
```

## OFFICIAL DEPENDENCIES ONLY

```
┌──────────────────────────────────────────────────────────┐
│                 flutter_keycheck                         │
│                                                          │
│  Uses ONLY Official Dart/Flutter Packages:              │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │    args    │  │  analyzer  │  │ ansicolor  │       │
│  │  (Official)│  │  (Official)│  │   (Pure    │       │
│  │    Dart    │  │    Dart    │  │    Dart)   │       │
│  └────────────┘  └────────────┘  └────────────┘       │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │   crypto   │  │    path    │  │    yaml    │       │
│  │  (Official)│  │  (Official)│  │  (Official)│       │
│  │    Dart    │  │    Dart    │  │    Dart    │       │
│  └────────────┘  └────────────┘  └────────────┘       │
│                                                          │
│         NO External/Third-Party Dependencies            │
└──────────────────────────────────────────────────────────┘
```
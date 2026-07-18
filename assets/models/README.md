# Bundled on-device models

## mobilefacenet.tflite

MobileFaceNet face-embedding model. Input `1×112×112×3` (RGB), output a
Float32 face-embedding vector (used for on-device people clustering — see
`lib/features/people/`).

- **Source:** https://github.com/MCarlomagno/FaceRecognitionAuth (`assets/mobilefacenet.tflite`)
- **License:** BSD 3-Clause — Copyright (c) Marcos Carlomagno
- **Usage:** bundled in the APK/IPA and run fully on-device via `tflite_flutter`.
  No network access at runtime (Absolute rule: zero network).

The BSD 3-Clause terms (redistribution + attribution) are satisfied by shipping
the model unmodified with this attribution.

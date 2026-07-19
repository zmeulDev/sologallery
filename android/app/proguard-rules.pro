# R8 rules for the release build.
#
# `google_mlkit_text_recognition` compiles against every script recognizer it
# supports and picks one at runtime from a MethodCall argument. We only ever ask
# for Latin (see MlService / the bundled Latin model), so the Chinese,
# Devanagari, Japanese, and Korean artifacts are not dependencies and their
# classes are genuinely absent — R8 must not fail the build over them.
#
# Adding those artifacts instead would ship four unused models and grow the APK
# for scripts the app never requests.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

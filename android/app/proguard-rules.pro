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

# ML Kit boots through `MlKitInitProvider`, which reflectively instantiates the
# `*Registrar` classes named in each artifact's manifest metadata. R8 cannot see
# those constructors being called, so it removes them and every ML Kit component
# silently fails to register:
#
#   W ComponentDiscovery: Invalid component registrar.
#   Could not instantiate com.google.mlkit.vision.face.internal.FaceRegistrar
#   Caused by: java.lang.NoSuchMethodException: …FaceRegistrar.<init> []
#
# The app still starts — ComponentDiscovery only warns — so this is invisible
# unless a *release* build is actually run on a device: labels, OCR, and faces
# would all come back empty in production while every debug test passed. Keep
# the no-arg constructors (the classes may still be renamed).
-keep,allowobfuscation class * implements com.google.firebase.components.ComponentRegistrar
-keepclassmembers class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
-keep,allowobfuscation class com.google.mlkit.**.*Registrar
-keepclassmembers class com.google.mlkit.**.*Registrar {
    <init>();
}

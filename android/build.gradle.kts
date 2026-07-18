allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    // The active JDK is 21, so Kotlin defaults its jvmTarget to 21 while Flutter
    // plugins keep Java lower — Gradle rejects the mismatch ("Inconsistent
    // JVM-target compatibility"). But plugins disagree on which Java level they
    // pin (photo_manager 17, google_mlkit_commons 11, google_mlkit_image_labeling
    // 1.8), and their Java `compileOptions` are finalized by AGP (can't be raised
    // from here). So instead of forcing a single Kotlin target, **match each
    // module's Kotlin target to its own Java target**, read lazily at task
    // configuration. See CLAUDE.md Known gotchas.
    //
    // `patrol` already pins both sides itself (1.8) and is left untouched.
    val selfConsistentModules = setOf("patrol")
    if (project.name !in selfConsistentModules) {
        project.plugins.withId("com.android.library") {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    val javaTarget = project.extensions
                        .getByType(com.android.build.gradle.LibraryExtension::class.java)
                        .compileOptions
                        .targetCompatibility
                    val kotlinTarget = when (javaTarget) {
                        JavaVersion.VERSION_1_8 ->
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                        JavaVersion.VERSION_11 ->
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                        else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                    }
                    compilerOptions { jvmTarget.set(kotlinTarget) }
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

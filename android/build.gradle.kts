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

    // The active JDK is 21, so Kotlin defaults its jvmTarget to 21 while
    // Flutter plugins (e.g. photo_manager) keep Java at 17 — Gradle rejects the
    // mismatch ("Inconsistent JVM-target compatibility"). Pin such subprojects'
    // Kotlin target to 17 to match the Java side. See CLAUDE.md Known gotchas.
    //
    // Skip modules that already pin *both* sides consistently at a lower level
    // (e.g. `patrol` sets Java **and** Kotlin to 1.8): forcing only their Kotlin
    // to 17 would *re-introduce* the mismatch. Their own config is left intact.
    val selfConsistentModules = setOf("patrol")
    if (project.name !in selfConsistentModules) {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

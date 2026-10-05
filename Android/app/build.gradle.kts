import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.mn.android"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.mn.android"
        // Swift's android SDK generates JNI wrappers at javaSourceLevel 17+,
        // which sets the floor for the whole app.
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    // jextract output from Scripts/build-android.sh --jextract. Not under
    // src/, so it has to be pointed at explicitly; without this the Kotlin side
    // cannot see com.mn.core at all.
    sourceSets {
        getByName("main") {
            java.srcDir("../../Packages/MeditateAndNoteCore/.generated/java")
        }
    }
}

// libMeditateAndNoteCore.so and libc++_shared.so land in
// src/main/jniLibs/arm64-v8a/ from Scripts/build-android.sh; AGP picks them up
// from there with no extra config.

dependencies {
    // Built by the swift-java checkout. Not on Maven Central under a stable
    // coordinate yet, so it is referenced as a local jar for now.
    implementation(files(swiftKitCoreJar()))

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.compose.ui:ui:1.7.6")
    implementation("androidx.compose.material3:material3:1.3.1")

    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")
}

/**
 * Resolves the swiftkit-core jar built by the swift-java checkout.
 *
 * Override with -PswiftJavaPath=/path/to/swift-java or the SWIFT_JAVA_PATH
 * environment variable; both build-android.sh and this file need the same
 * checkout, and if they disagree the app compiles against a different
 * SwiftArena API than the one the .so was built with.
 */
fun swiftKitCoreJar(): File {
    val root = (project.findProperty("swiftJavaPath") as String?)
        ?: System.getenv("SWIFT_JAVA_PATH")
        ?: error(
            "Point me at the swift-java checkout: -PswiftJavaPath=/path/to/swift-java " +
                "or SWIFT_JAVA_PATH. Needed for org.swift.swiftkit.core (SwiftArena)."
        )
    val jar = File(root, "SwiftKitCore/build/libs/swiftkit-core-d6ff36c.jar")
    check(jar.exists()) {
        "swiftkit-core jar not built. Run: cd $root && ./gradlew :SwiftKitCore:jar"
    }
    return jar
}
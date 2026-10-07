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

/**
 * Rebuilds the Swift core into src/main/jniLibs before AGP packages it.
 *
 * Without this the APK happily ships whatever .so was there last, so a Swift
 * edit shows up as "my change did nothing" rather than as a build failure. The
 * task is up-to-date-checked on the Swift sources and the build script, so an
 * ordinary Kotlin/Compose edit does not pay for a Swift rebuild.
 */
val swiftCoreDir = file("$rootDir/../Packages/MeditateAndNoteCore/Sources/MeditateAndNoteCore")
val buildScript = rootProject.file("../Scripts/build-android.sh")
val swiftJavaHomeFile = swiftJavaHome()

val swiftCore by tasks.registering(Exec::class) {
    group = "build"
    description = "Compiles MeditateAndNoteCore for Android into src/main/jniLibs"

    workingDir = rootProject.projectDir.parentFile
    commandLine(buildScript.absolutePath)

    environment("SWIFT_JAVA_HOME", swiftJavaHomeFile.absolutePath)

    inputs.dir(swiftCoreDir).withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.file(buildScript)
    inputs.property("swiftJavaHome", swiftJavaHomeFile.absolutePath)
    outputs.dir(file("src/main/jniLibs"))
    outputs.dir("$rootDir/../Packages/MeditateAndNoteCore/.generated/java")

    // jextract's warnings about un-annotated properties and unimplemented types
    // are its own gaps in coverage, not failures of this build; a nonzero exit
    // is what matters.
    isIgnoreExitValue = false
}

tasks.named("preBuild") {
    dependsOn(swiftCore)
}

dependencies {
    // Built by the swift-java checkout. Not on Maven Central under a stable
    // coordinate yet, so it is referenced as a local jar for now.
    implementation(files(swiftKitCoreJar()))

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.compose.ui:ui:1.7.6")
    implementation("androidx.compose.material3:material3:1.3.1")
    implementation("androidx.navigation:navigation-compose:2.8.4")
    // Onboarding slides mirror the SF Symbols placeholders in OnboardingPage
    // (leaf / note.text / flame). None of those are in the core icon set, and
    // R8 shrinks the rest away.
    implementation("androidx.compose.material:material-icons-extended:1.7.6")

    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")
}

/**
 * Resolves the swiftkit-core jar built by the swift-java checkout.
 *
 * Order: -PswiftJavaPath, then SWIFT_JAVA_PATH, then ~/Developer/swift-java.
 * A default exists because this runs during configuration, and demanding a flag
 * made even `gradle wrapper` fail. build-android.sh resolves the checkout the
 * same way, so the two cannot silently disagree about which SwiftArena API the
 * app compiles against.
 */
fun swiftJavaHome(): File {
    val fromProp = (project.findProperty("swiftJavaPath") as String?)
    val fromEnv = System.getenv("SWIFT_JAVA_PATH")
    val home = File(
        when {
            fromProp != null -> fromProp
            fromEnv != null -> fromEnv
            else -> "${System.getProperty("user.home")}/Developer/swift-java"
        }
    )
    check(home.isDirectory) {
        "swift-java checkout not found at $home. Set -PswiftJavaPath=/path/to/swift-java " +
            "or SWIFT_JAVA_PATH."
    }
    return home
}

fun swiftKitCoreJar(): File {
    val root = swiftJavaHome()
    val jar = File(root, "SwiftKitCore/build/libs/swiftkit-core-d6ff36c.jar")
    check(jar.exists()) {
        "swiftkit-core jar not built. Run: cd $root && ./gradlew :SwiftKitCore:jar"
    }
    return jar
}
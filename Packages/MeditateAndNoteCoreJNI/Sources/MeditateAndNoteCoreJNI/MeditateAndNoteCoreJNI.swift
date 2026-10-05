//
//  MeditateAndNoteCoreJNI.swift
//  MeditateAndNoteCoreJNI
//
//  Android-only target. Its whole job is to compile the jextract-generated
//  thunks so the JNI entry points actually exist inside
//  libMeditateAndNoteCore.so.
//
//  Without this, the Java side loads fine and then fails at the first call with:
//
//    No implementation found for long
//    com.mn.core.InMemoryAIDraftMetricStore.$init(long[])
//      - is the library loaded, e.g. System.loadLibrary?
//
//  The `@_cdecl("Java_...")` functions live in the generated files; nothing in
//  MeditateAndNoteCore references them, so without a target that compiles them
//  they get dropped and the .so has no entry points for Kotlin to call.
//

// Swift's generated thunks are compiled from this directory; see
// Scripts/build-android.sh --jextract, which copies them in.
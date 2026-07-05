# VibeNime ProGuard / R8 keep rules
# Aplikasi pakai reflection di beberapa lib — jangan obfuscate kelas-kelas ini.

# --- Flutter Engine ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# --- Riverpod / json deserialization (pakai mirror di debug) ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Supabase / GoTrue / Realtime ---
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# --- GraphQL Flutter ---
-keep class graphql.** { *; }
-dontwarn graphql.**

# --- Better Player / ExoPlayer ---
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn com.google.android.exoplayer.**

# --- Hive (CE generated adapters) ---
-keep class * extends hive.adapter.** { *; }
-keep @hive.HiveType class * { *; }

# --- Dio / OkHttp ---
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# --- Generic ---
-dontwarn java.lang.invoke.StringConcatFactory
-keepattributes SourceFile,LineNumberTable

# Hide source file names but keep line numbers (untuk stacktrace di Sentry)
-renamesourcefileattribute SourceFile

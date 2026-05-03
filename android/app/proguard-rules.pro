# Gson — used in Glance/home_widget Android layer
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# WorkManager — discovers task classes by name via reflection
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Sentry — uses reflection for stack trace symbolication
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# flutter_local_notifications — notification callback receivers
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# background_downloader — background task dispatchers
-keep class com.bbflight.background_downloader.** { *; }
-dontwarn com.bbflight.background_downloader.**

# home_widget / Glance — widget receiver and update classes
-keep class es.antonborri.home_widget.** { *; }
-dontwarn es.antonborri.home_widget.**

# flutter_secure_storage — uses reflection for EncryptedSharedPreferences (OAuth tokens)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

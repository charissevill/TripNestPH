# Firebase / Google Play Services — keep everything, these ship their own
# reflection-based initialization that R8 can't trace statically.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Maps
-keep class com.google.android.libraries.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# Gson (pulled in transitively by some Google/Firebase libraries) relies on
# generic type signatures that R8 strips by default.
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

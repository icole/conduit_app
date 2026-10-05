# Hotwire, Stream, Firebase and Google sign-in ship their own rules.

# Our code is small; keeping it whole keeps reflection safe (Hotwire finds
# bridge message serializers and fragment deep-link annotations by class)
# and crash reports readable. R8 still shrinks the libraries.
-keep class com.colecoding.conduit.** { *; }
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault,InnerClasses,Signature,SourceFile,LineNumberTable

# kotlinx.serialization looks up a @Serializable class's serializer reflectively
-keepclassmembers @kotlinx.serialization.Serializable class ** {
    static ** Companion;
    *** Companion;
}
-if @kotlinx.serialization.Serializable class ** {
    static **$* *;
}
-keepclassmembers class <2>$<3> {
    kotlinx.serialization.KSerializer serializer(...);
}
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1>$Companion {
    kotlinx.serialization.KSerializer serializer(...);
}

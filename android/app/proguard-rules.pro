# Rules for shrinking the release app (R8).
# Google's text reader also knows Chinese, Devanagari, Japanese and Korean readers,
# but Gamy only includes the Latin one (English/Filipino). These lines say that's fine.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

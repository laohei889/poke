# ProGuard / R8 规则
#
# device_calendar 插件用 Gson 反射序列化日历/事件模型（Calendar/Event/...），
# R8 混淆会把 Kotlin 模型的字段名改掉，导致 retrieveCalendars() 返回的日历
# id/name 全为 null（表现为：日历列表"未命名日历"、无法点选、
# 自动使用默认日历提示"未找到系统日历"）。
# 官方 README 指定的修复方式：保留整个插件包。
-keep class com.builttoroam.devicecalendar.** { *; }

# Gson 反射序列化的通用保护（泛型签名、注解、TypeToken 子类）
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers class * implements com.google.gson.JsonSerializer { *; }
-keepclassmembers class * implements com.google.gson.JsonDeserializer { *; }

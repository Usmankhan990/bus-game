# Release build mein R8 code chhota karta hai. Kuch classes naam se (reflection) bani hain,
# unhein R8 hata deta hai aur app khulte hi crash ho jaati hai. Yeh rules unhein bachate hain.

# AdMob SDK ke saath aane wali WorkManager aur Room library ka database
# (warna crash: "Failed to create an instance of androidx.work.impl.WorkDatabase")
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**

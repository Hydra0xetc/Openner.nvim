package com.activity.lister;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.FileWriter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class AppScanner
{

    public static void scanAndSave(Context context)
    {
        Map<String, AppEntry> map = new LinkedHashMap<>();
        
        PackageManager pm = context.getPackageManager();
        Intent intent = new Intent(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_LAUNCHER);
        
        List<ResolveInfo> list = pm.queryIntentActivities(intent, 0);
        
        for (ResolveInfo info : list) {
            String pkg = info.activityInfo.packageName;
            String act = info.activityInfo.name;
            String appName = info.loadLabel(pm).toString();
            
            if (!map.containsKey(pkg)) {
                map.put(pkg, new AppEntry(pkg, appName));
            }
            map.get(pkg).activities.add(act);
        }
        
        saveJson(context, map);
    }

    private static void saveJson(Context context, Map<String, AppEntry> map)
    {
        try {
            JSONArray jsonArray = new JSONArray();
            
            for (AppEntry entry : map.values()) {
                JSONObject obj = new JSONObject();
                obj.put("appName", entry.appName);
                obj.put("packageName", entry.packageName);
                
                JSONArray activities = new JSONArray();
                for (String activity : entry.activities) {
                    activities.put(activity);
                }
                obj.put("activities", activities);
                
                jsonArray.put(obj);
            }
            
            File path = context.getExternalFilesDir(null);
            if (path != null) {
                File file = new File(path, "activities.json");
                FileWriter writer = new FileWriter(file);
                writer.write(jsonArray.toString(2)); // Pretty print with 2 indent
                writer.close();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

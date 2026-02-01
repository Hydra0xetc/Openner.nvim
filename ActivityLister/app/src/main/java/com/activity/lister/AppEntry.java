package com.activity.lister;

import java.util.ArrayList;
import java.util.List;

public class AppEntry {
    public String appName;
    public String packageName;
    public List<String> activities = new ArrayList<>();

    public AppEntry(String packageName, String name) {
        this.packageName = packageName;
        this.appName = name;
    }
}

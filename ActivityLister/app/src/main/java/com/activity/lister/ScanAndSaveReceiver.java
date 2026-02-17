package com.activity.lister;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class ScanAndSaveReceiver extends BroadcastReceiver
{
    @Override
    public void onReceive(Context context, Intent intent)
    {
        if ("com.activity.lister.ACTION_SCAN_AND_SAVE".equals(intent.getAction())) {
            AppScanner.scanAndSave(context);
        }
    }
}

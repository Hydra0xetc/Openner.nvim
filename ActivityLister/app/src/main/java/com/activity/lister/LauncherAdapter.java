package com.activity.lister;

import android.content.Context;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.recyclerview.widget.RecyclerView;

import java.util.Collection;

public class LauncherAdapter extends RecyclerView.Adapter<LauncherAdapter.VH> {

    private final Context context;
    private final AppEntry[] data;

    public LauncherAdapter(Context c, Collection<AppEntry> list) {
        context = c;
        data = list.toArray(new AppEntry[0]);
    }

    static class VH extends RecyclerView.ViewHolder {
        TextView pkg;
        TextView appName;
        LinearLayout container;

        VH(View v) {
            super(v);
            pkg = v.findViewById(R.id.pkgName);
            appName = v.findViewById(R.id.appName);
            container = v.findViewById(R.id.activityContainer);
        }
    }

    @Override
    public VH onCreateViewHolder(ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(context)
                .inflate(R.layout.item_app, parent, false);
        return new VH(v);
    }

    @Override
    public void onBindViewHolder(VH h, int pos) {
        AppEntry app = data[pos];
        h.pkg.setText(app.packageName);
        h.appName.setText(app.appName);
        h.container.removeAllViews();

        for (String act : app.activities) {
            View v = LayoutInflater.from(context)
                    .inflate(R.layout.item_activity, h.container, false);

            TextView tv = v.findViewById(R.id.activityName);
            tv.setText(act);

            v.setOnClickListener(x -> {
                try {
                    Intent i = new Intent();
                    i.setClassName(app.packageName, act);
                    context.startActivity(i);
                } catch (Exception e) {
                    Toast.makeText(context,
                            "Activity tidak bisa dibuka",
                            Toast.LENGTH_SHORT).show();
                }
            });

            h.container.addView(v);
        }
    }

    @Override
    public int getItemCount() {
        return data.length;
    }
}

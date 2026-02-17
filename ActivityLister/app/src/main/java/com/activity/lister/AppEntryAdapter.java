package com.activity.lister;

import com.google.gson.Gson;
import com.google.gson.TypeAdapter;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonWriter;

import java.io.IOException;

public class AppEntryAdapter extends TypeAdapter<AppEntry>
{
    @Override
    public void write(JsonWriter out, AppEntry appEntry) throws IOException
    {
        out.beginObject();
        out.name("appName").value(appEntry.appName);
        out.name("packageName").value(appEntry.packageName);
        out.name("activities");
        Gson gson = new Gson(); // Use the same Gson instance for nested serialization
        gson.toJson(gson.toJsonTree(appEntry.activities), out);
        out.endObject();
    }

    @Override
    public AppEntry read(JsonReader in) throws IOException
    {
        // Implement if you need to deserialize JSON back to AppEntry
        // For this task, we only need serialization, so this can be left unimplemented
        // or throw an UnsupportedOperationException
        in.skipValue(); // Consume the unread value to avoid issues
        return null; // Or throw new UnsupportedOperationException("Deserialization not supported");
    }
}
